% MAIN.m  --  Five Link Biped trajectory optimization
%
% This script sets up and then solves the optimal trajectory for the five
% link biped, assuming that the walking gait is compused of single-stance
% phases of motion connected by impulsive heel-strike (no double-stance or
% flight phases).
%

clc; clear;

param = getPhysicalParameters();

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                       Set up function handles                           %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

problem.func.dynamics =  @(t,x,u)( dynamics(x,u,param) );

problem.func.pathObj = @(t,x,u)( sum(u.^2, 1) );

problem.func.bndCst = @(t0,x0,tF,xF)( stepConstraint(xF,x0,param) );


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%               Set up bounds on time, state, and control                 %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
t0 = 0;  tF = 0.8;
problem.bounds.initialTime.low = t0;
problem.bounds.initialTime.upp = t0;
problem.bounds.finalTime.low = tF;
problem.bounds.finalTime.upp = tF;

% State: (absolute reference frames)
%   1 = stance leg tibia angle
%   2 = stance leg femur angle
%   3 = torso angle
%   4 = swing leg femur angle
%   5 = swing leg tibia angle

qLow = (-pi/2)*ones(5,1);
qUpp = (pi/2)*ones(5,1);
dqLow = -10*ones(5,1);
dqUpp = 10*ones(5,1);
problem.bounds.state.low = [qLow; dqLow];
problem.bounds.state.upp = [qUpp; dqUpp];
problem.bounds.initialstate.low = [qLow; dqLow];
problem.bounds.initialstate.upp = [qUpp; dqUpp];
problem.bounds.finalstate.low = [qLow; dqLow];
problem.bounds.finalstate.upp = [qUpp; dqUpp];

uMax = 100;  %Nm
problem.bounds.control.low = -uMax*ones(5,1);
problem.bounds.control.upp = uMax*ones(5,1);


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%              Create an initial guess for the trajectory                 %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

% For now, just assume a linear trajectory between boundary values

problem.guess.time = [t0, tF];

q0 = [...
    -0.3; % stance leg tibia angle
    0.7; % stance leg femur angle
    0.0; % torso angle
    -0.5; % swing leg femur angle
    -0.6]; % swing leg tibia angle
qF = heelStrikeMap(q0,zeros(5,1),param);

dq0 = (qF-q0)/(tF-t0);
dqF = dq0;

problem.guess.state = [q0, qF; dq0, dqF];

problem.guess.control = zeros(5,2);  %Start with passive trajectory


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                           Options:                                      %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%


%NOTE:  Here I choose to run the optimization twice, mostly to demonstrate
%   functionality, although this can be important on harder problems. I've
%   explicitly written out many options below, but the solver will fill in
%   almost all defaults for you if they are ommitted.

method = 'trapazoid';
% method = 'hermiteSimpson';
% method = 'chebyshev';
% method = 'multiCheb';
% method = 'rungeKutta';

%%%% Method-independent options:
problem.options(1).nlpOpt = optimset(...
    'Display','iter',...   % {'iter','final','off'}
    'TolFun',1e-3,...
    'MaxFunEvals',1e4);   %options for fmincon
problem.options(2).nlpOpt = optimset(...
    'Display','iter',...   % {'iter','final','off'}
    'TolFun',1e-6,...
    'MaxFunEvals',5e4);   %options for fmincon


switch method
    case 'trapazoid'
        problem.options(1).method = 'trapazoid'; % Select the transcription method
        problem.options(1).trapazoid.nGrid = 10;  %method-specific options
        
        problem.options(2).method = 'trapazoid'; % Select the transcription method
        problem.options(2).trapazoid.nGrid = 25;  %method-specific options
        
    case 'hermiteSimpson'
        
        % First iteration: get a more reasonable guess
        problem.options(1).method = 'hermiteSimpson'; % Select the transcription method
        problem.options(1).hermiteSimpson.nSegment = 6;  %method-specific options
        
        % Second iteration: refine guess to get precise soln
        problem.options(2).method = 'hermiteSimpson'; % Select the transcription method
        problem.options(2).hermiteSimpson.nSegment = 15;  %method-specific options
        
        
    case 'chebyshev'
        
        % First iteration: get a more reasonable guess
        problem.options(1).method = 'chebyshev'; % Select the transcription method
        problem.options(1).chebyshev.nColPts = 9;  %method-specific options
        
        % Second iteration: refine guess to get precise soln
        problem.options(2).method = 'chebyshev'; % Select the transcription method
        problem.options(2).chebyshev.nColPts = 15;  %method-specific options
        
    case 'multiCheb'
        
        % First iteration: get a more reasonable guess
        problem.options(1).method = 'multiCheb'; % Select the transcription method
        problem.options(1).multiCheb.nColPts = 6;  %method-specific options
        problem.options(1).multiCheb.nSegment = 4;  %method-specific options
        
        % Second iteration: refine guess to get precise soln
        problem.options(2).method = 'multiCheb'; % Select the transcription method
        problem.options(2).multiCheb.nColPts = 9;  %method-specific options
        problem.options(2).multiCheb.nSegment = 4;  %method-specific options
        
    case 'rungeKutta'
        problem.options(1).method = 'rungeKutta'; % Select the transcription method
        problem.options(1).defaultAccuracy = 'low';
        problem.options(2).method = 'rungeKutta'; % Select the transcription method
        problem.options(2).defaultAccuracy = 'medium';
        
    otherwise
        error('Invalid method!');
end



%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                           Solve!                                        %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

%%%%% THE KEY LINE:
soln = trajOpt(problem);

% Transcription Grid points:
t = soln(end).grid.time;
q = soln(end).grid.state(1:5,:);
dq = soln(end).grid.state(6:10,:);
u = soln(end).grid.control;


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                     Plot the solution                                   %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%