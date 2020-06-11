
% test_signal与test_object均用于测试PairTradingSignal class, 这部分由李佳辉负责开发
% code review: 何隽贤
% Writer : Li Jiahui 
% Date: 2020/06/06
% 第三次修改后结果


%use test object to generate signals
%dateLocation is the location of date in test.dateList. 
%For example, dateLocation of 20111031 is 200.
%dateLocation is adjustable for convenience of reuse.
dateLocation = 200;
dateCode = test.dateList{dateLocation,1};
%generate signals of given date
test.generateSignals(dateCode);
b = test.signalParameters;
%cointPairs is used for storing cointegrated pairs and their siganl parameters
cointPairs = [];
%select cointegrated pairs and store pairs into cointPairs together with their performance
for stock1 = 1:1:41
    for stock2 = stock1:1:42
        if b(stock1,stock2,dateLocation,1,1,1) == 1
            cointPairs = [cointPairs;[test.stockUniverse(stock1,2),test.stockUniverse(stock2,2),b(stock1,stock2,dateLocation,1,1,2),b(stock1,stock2,dateLocation,1,1,3),b(stock1,stock2,dateLocation,1,1,4),b(stock1,stock2,dateLocation,1,1,5),b(stock1,stock2,dateLocation,1,1,6),b(stock1,stock2,dateLocation,1,1,7),b(stock1,stock2,dateLocation,1,1,8)]];
            
        end
    end
end