classdef LongOnly < mclasses.strategy.LFBaseStrategy
    methods
        function obj = LongOnly(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
        end
    end
    
    methods
        function [orderList, delayList] = generateOrders(obj, currDate, ~)
            orderList = [];
            delayList = [];
            
            currAvailableCapital = obj.calNetWorth(currDate);
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);

            stFilter = ~aggregatedDataStruct.stock.stTable(dateLoc, :);
            suspensionFilter = aggregatedDataStruct.stock.tradeDayTable(dateLoc, :);
            currFilter = stFilter & suspensionFilter;
            numOfStocksSelected = 10;
            selectedStockLoc = find(currFilter, numOfStocksSelected);
            windTickers = aggregatedDataStruct.stock.description.tickers.windTicker(selectedStockLoc);
            aggregatedDataStruct.stock.description.tickers.shortName(selectedStockLoc)
            selectedPrices = aggregatedDataStruct.stock.properties.(obj.orderPriceType)(dateLoc, selectedStockLoc);
            targetLongPosition = floor(currAvailableCapital*0.85/numOfStocksSelected ./selectedPrices /100)*100;
            
            longAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            longAdjustOrder.account = obj.accounts('stockAccount');
            longAdjustOrder.price = obj.orderPriceType;
            longAdjustOrder.assetCode = windTickers;
            longAdjustOrder.quantity = targetLongPosition;
            
            orderList = [orderList, longAdjustOrder];
            delayList = [delayList, 1];
        end
    end
end
