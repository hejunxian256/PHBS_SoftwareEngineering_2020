%% This file serves as a test script for the LongOnly strategy

%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_1');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(2014, 5, 1);
initParameters.endDate = datenum(2014, 8, 31);
director.initialize(initParameters);

% register a long only strategy
longOnlyStrategy = mclasses.strategy.longOnly.LongOnly(director.rootAllocator , 'longOnly');
strategyParameters = mclasses.strategy.longOnly.configParameter(longOnlyStrategy);
longOnlyStrategy.initialize(strategyParameters);

%% run strategies
%load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
director.set_tradeDates(aggregatedDataStruct.sharedInformation.allDates);
director.run();

%% display results
director.displayResult();
