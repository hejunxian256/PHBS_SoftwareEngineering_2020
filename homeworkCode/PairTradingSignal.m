classdef PairTradingSignal < handle
    
    properties(Access = public)
        startDate;
        %startDateLocation is the location of startDate in dateList
        startDateLocation;
        regressionBetaHistory = [];
        regressionAlphaHistory = [];
        forwardPrices = [];
        wr = 100;
        ws = 30;
        stockLocation;
        stockNum = 42;
        %sigalParameters has six dimensions:stock1,stock2,dateLocation,wr,ws and properties
        %dateLocation is the location of date in dateList
        %properties have right parameters listed in propertyParameters
        signalParameters = zeros(1,1,1,1,1,8)
        propertyNameList =  {'validity','zScore','dislocation','expectedReturn','halfLife','entryPointBoundary','alpha','beta'};
        stockUniverse;
        %dateList is 2210*2 cell; the first column is date code, the second column is actual date
        dateList;
    end
    
    methods
        function obj = PairTradingSignal(startDateCode)
            obj.startDate = startDateCode;
            %store stock prices into forwardPrices
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            generalData = marketData.getAggregatedDataStruct;
            stockSectorFilter = generalData.stock.sectorClassification.levelOne == 4;
            stockLocation = find(sum(stockSectorFilter) > 1);
            obj.stockLocation = stockLocation;
            obj.forwardPrices = generalData.stock.properties.fwd_close(:, stockLocation);
            %store actual stock name and code into stockUniverse
            code=generalData.stock.description.tickers.officialTicker(stockLocation);
            shortname = generalData.stock.description.tickers.shortName(stockLocation);
            obj.stockUniverse = [code,shortname];
            %for i-th stock, obj.stockUniverse{i,1} returns its stock code 
            %and obj.stockUniverse{i,2} returns its name
            %store actual date into dateList
            dateId = generalData.sharedInformation.allDates;
            realDate = generalData.sharedInformation.allDateStr;
            dateId = num2cell(dateId);
            realDate = cellstr(realDate);
            obj.dateList = [dateId, realDate];
            %initialize the obj.startDateLocation
            obj.startDateLocation = find(cell2mat(obj.dateList(:,1)) == obj.startDate);
        end
        
        %calculate ws-1 days' alpha and beta of all pairs before startDate
        function obj = initializeHistory(obj)
            for stock1 = 1:1:obj.stockNum-1
                for stock2 = stock1+1:1:obj.stockNum
                    for dateLocation = obj.startDateLocation - obj.ws + 1:1:obj.startDateLocation - 1
                        Y = obj.forwardPrices(dateLocation-obj.wr+1:dateLocation,stock1);
                        X = obj.forwardPrices(dateLocation-obj.wr+1:dateLocation,stock2);
                        %count the number of NaN in Y and X
                        YNaNNum = sum(isnan(Y));
                        XNaNNum = sum(isnan(X));
                        %if there are NaNs in Y and X or prices of stock1 or stock2 didn't change over time, fill NaN into regression history
                        if YNaNNum+XNaNNum >= 1 || max(Y)-min(Y) == 0 || max(X)-min(X) == 0
                            obj.regressionAlphaHistory(stock1,stock2,dateLocation) = NaN;
                            obj.regressionBetaHistory(stock1,stock2,dateLocation) = NaN;
                        else
                            [b,~,~,~,~] = regress(Y,[ones(obj.wr,1), X]);
                            obj.regressionAlphaHistory(stock1,stock2,dateLocation) = b(1);
                            obj.regressionBetaHistory(stock1,stock2,dateLocation) = b(2);
                        end
                    end
                end
            end
        end
        
        %calculate the parameters of stock1 and stock2 at given date
        function obj = calculateParameters(obj,stock1,stock2,dateCode,alpha,beta,residual)
            dateLocation = find(cell2mat(obj.dateList(:,1)) == dateCode);
            %calculate dislocation
            dislocation = obj.forwardPrices(dateLocation,stock1)-beta*obj.forwardPrices(dateLocation,stock2) - alpha;
            obj.signalParameters(stock1,stock2,dateLocation,1,1,3) = dislocation;
            %calculate z-score
            zScore = dislocation/std(residual);
            obj.signalParameters(stock1,stock2,dateLocation,1,1,2) = zScore;
            %calculate halflife
            Y = residual(2:obj.ws);
            X = [ones(obj.ws-1,1),residual(1:obj.ws-1)];
            [b ,~ , ~ ,~ , ~] = regress(Y,X);
            halfLife = -log(b(2))*256;
            obj.signalParameters(stock1,stock2,dateLocation,1,1,5) = halfLife;
            %calculate expeted return
            tradingCost = obj.forwardPrices(dateLocation,stock1)+abs(beta)*obj.forwardPrices(dateLocation,stock2);
            expectedReturn = abs(dislocation)/(2*tradingCost)/(halfLife/256);
            obj.signalParameters(stock1,stock2,dateLocation,1,1,4) = expectedReturn;
            %calculate entry point boundary
            boundary = alpha + 2*std(residual);
            obj.signalParameters(stock1,stock2,dateLocation,1,1,6) = boundary;
        end
        
        %calculate all the pairs parameters
        function obj = generateSignals(obj,dateCode)
            dateLocation = find(cell2mat(obj.dateList(:,1)) == dateCode);
            for stock1 = 1:1:obj.stockNum-1
                for stock2 = stock1+1:1:obj.stockNum
                    %calculate the current day's alpha and beta and store them into regression history
                    Y = obj.forwardPrices(dateLocation-obj.wr+1:dateLocation,stock1);
                    X = obj.forwardPrices(dateLocation-obj.wr+1:dateLocation,stock2);
                    YNaNNum = sum(isnan(Y));
                    XNaNNum = sum(isnan(X));
                    if YNaNNum+XNaNNum >= 1 || max(Y)-min(Y) == 0 || max(X)-min(X) == 0
                        obj.regressionAlphaHistory(stock1,stock2,dateLocation) = NaN;
                        obj.regressionBetaHistory(stock1,stock2,dateLocation) = NaN;
                    else
                        [b,~,~,~,~] = regress(Y,[ones(obj.wr,1), X]);
                        obj.regressionAlphaHistory(stock1,stock2,dateLocation) = b(1);
                        obj.regressionBetaHistory(stock1,stock2,dateLocation) = b(2); 
                    end
                    alphaNaNNum = sum(isnan(obj.regressionAlphaHistory(stock1,stock2,dateLocation - obj.ws + 1:dateLocation)));
                    betaNaNNum = sum(isnan(obj.regressionBetaHistory(stock1,stock2,dateLocation - obj.ws + 1:dateLocation)));
                    %if there are NaNs in regression history, then this pair is not valid and set all the parameters 0.
                    stockPrice1 = obj.forwardPrices(dateLocation - obj.ws + 1:dateLocation,stock1);
                    stockPrice2 = obj.forwardPrices(dateLocation - obj.ws + 1:dateLocation,stock2);
                    %if stock prices don't change in the past ws days, then this pair is not valid.
                    if alphaNaNNum+betaNaNNum >= 1 || max(stockPrice1)-min(stockPrice1) == 0 || max(stockPrice2)-min(stockPrice2) == 0
                        obj.signalParameters(stock1,stock2,dateLocation,1,1,:) = zeros(8,1);
                    else
                        averageAlpha = mean(obj.regressionAlphaHistory(stock1,stock2,dateLocation - obj.ws + 1:dateLocation));
                        averageBeta = mean(obj.regressionBetaHistory(stock1,stock2,dateLocation - obj.ws + 1:dateLocation));
                        residual = stockPrice1 - averageAlpha - averageBeta*stockPrice2;
                        validity = adftest(residual);
                        %if residual series is staionary, then calculate and store parameters 
                        if validity == 1
                            obj.signalParameters(stock1,stock2,dateLocation,1,1,1) = validity;
                            obj.signalParameters(stock1,stock2,dateLocation,1,1,7) = averageAlpha;
                            obj.signalParameters(stock1,stock2,dateLocation,1,1,8) = averageBeta;
                            obj.calculateParameters(stock1,stock2,dateCode,averageAlpha,averageBeta,residual);
                        %if residual series is not stationary, then all the parameters are 0
                        else
                            obj.signalParameters(stock1,stock2,dateLocation,1,1,:) = zeros(8,1);
                        end
                    end
                end
            end
        end
    end   
end