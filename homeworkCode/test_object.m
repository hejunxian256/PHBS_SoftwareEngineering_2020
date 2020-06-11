
% test_signl与test_object均用于测试PairTradingSignal class, 这部分由李佳辉负责开发
% code review: 何隽贤
% Writer : Li Jiahui 
% Date: 2020/06/06
% 第二次修改后结果

%generate the a test object of PairTradingSignal class with start date 20111031
%'734807' is the time stamp corresponding to the date 20111031
test = PairTradingSignal(734807);
%fill 29 days alpha and beta history into regressionAlphaHistory and regressionBetaHistory
test.initializeHistory;