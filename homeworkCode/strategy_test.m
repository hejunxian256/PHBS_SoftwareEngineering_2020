%% This file serves as a test script for the LongOnly strategy

%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_1');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(2017, 1, 1);
initParameters.endDate = datenum(2020,2 , 2);
director.initialize(initParameters);

% register a strategy
PairTradingStrategyInstance =  PairTradingStrategy(director.rootAllocator , 'pairTradingStrategy');
%2020/06/11��͢�����޸��˴˴������������ܺ�.m�ļ�����
strategyParameters = mclasses.strategy.longOnly.configParameter(PairTradingStrategyInstance);
PairTradingStrategyInstance.initialize(strategyParameters);

%% run strategies
load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
director.set_tradeDates(aggregatedDataStruct.sharedInformation.allDates);
director.run();
director.displayResult();