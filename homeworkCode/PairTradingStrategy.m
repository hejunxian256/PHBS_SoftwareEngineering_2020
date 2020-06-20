%%
%PairTradingStrategy部分由李方闻，宗艳洁共同开发
%宗艳洁负责fields与constructor,generateOrders,examCurrPairList以及autoupdateCurrPairListPnL方法的编写
%李方闻负责updateCurrPairList,orderSort,openPair与closePair 方法的编写

% Writer : Zong Yanjie
% Date: 2020/06/06
% 第二次修改后结果
% code review: 沈廷威，何隽贤
classdef PairTradingStrategy < mclasses.strategy.LFBaseStrategy
    
    properties(Access = public)
        signals;
        signalInitialized;
        openCounter;
        winCounter;
        lossCounter;
        existPair;
        cutLossRecord;
        noValidation;
        cutLossCounter;
        stopWinCounter ;
        exchangeStopCounter;
        currPairList;
    end
    
    methods
        function obj = PairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
            obj.signalInitialized = 0;
            obj.winCounter=0;
            obj.lossCounter =0;
            obj.existPair = 0;
            obj.cutLossRecord=0;
            obj.openCounter=0;
            obj.noValidation=0;
            obj.cutLossCounter=0;
            obj.stopWinCounter =0;
            obj.exchangeStopCounter=0;
            obj.currPairList = cell(0);
        end
    
        %% update the current pairtrading list through self-update,
        % examination and profit sorting.Then generate the Orders to be
        % trade tomorrow
        
        function [orderList, delayList] = generateOrders(obj, currDate, ~)
            orderList = [];
            delayList = [];
            if not(obj.signalInitialized)
               obj.signals = PairTradingSignal(currDate);%currDate=735722
               obj.signals.initializeHistory;
               obj.signalInitialized =1;
               obj.signals.generateSignals(currDate);
               obj.winCounter=obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0; %记录每个pair盈利总个数
               obj.lossCounter =obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0; %记录每个pair亏损总个数
               obj.cutLossCounter =obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0; %记录每个pair止损总个数
               obj.stopWinCounter =obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0;%记录每个pair止盈总个数
               obj.existPair = obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0; %记录存在的pair，是，位置则为1，否则为0
               obj.cutLossRecord=obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0-1; %记录该pair是否在止损线定期内，是则大于0
               obj.openCounter=obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0; %记录每个pair总的开仓次数
               obj.noValidation = obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0;%记录每个pair因为协整关系失效而关仓总次数
               obj.exchangeStopCounter = obj.signals.signalParameters( : , : , 1 , 1 , 1 , 1 )*0;%记录每个pair因为换仓而关仓总次数

            end

            obj.signals.generateSignals(currDate);
            obj.autoupdateCurrPairListPnL(currDate);
            [buyOrderList1, sellOrderList1] = obj.examCurrPairList(currDate);
            [buyOrderList2,sellOrderList2] = obj.updateCurrPairList(currDate);
            order = {sellOrderList1,sellOrderList2,buyOrderList1,buyOrderList2} ;
            obj.cutLossRecord = obj.cutLossRecord-1;%止损截止日期减1
            for i =1:4
               if ~isempty(order{i}.assetCode)
                   orderList=[orderList, order{i}];
                end
            end
            [~,orderCount] = size(orderList);
            delayList = ones(1,orderCount);
            obj.cutLossRecord = obj.cutLossRecord-1;
            if (currDate==datenum(2017, 4,27 ))
                xlswrite('winCounter.xls',obj.winCounter);
                xlswrite('lossCounter.xls',obj.lossCounter);
                xlswrite('cutLossCounter.xls',obj.cutLossCounter);
                xlswrite('stopWinCounter.xls',obj.stopWinCounter);
                xlswrite('openCounter.xls',obj.openCounter);
                xlswrite('noValidation.xls',obj.noValidation);
                xlswrite('exchangeStopCounter.xls',obj.exchangeStopCounter);
            end
        end
        
        
        %% close the position while certain loss is beyond the level or the pairs back to the mean.
       function [ buyOrderList, sellOrderList] = examCurrPairList(obj,currDate) 
            zscoreIndex = find(ismember(obj.signals.propertyNameList, 'zScore'));
            currentZscore = obj.signals.signalParameters(:,:,end,1,1,zscoreIndex);
            validityIndex = find(ismember(obj.signals.propertyNameList, 'validity'));
            currentVal = obj.signals.signalParameters(:,:,end,1,1,validityIndex);
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;

            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            newList = {};
            sign = false; %the signal whether to close the position, set it here in case the currPairList is null
            for i=1:length(obj.currPairList)
                x1 = find(ismember(obj.signals.stockLocation,obj.currPairList{1,i}.stock1));
                x2 = find(ismember(obj.signals.stockLocation,obj.currPairList{1,i}.stock2));
                sign=false;%the signal whether to close the position
                
                if (obj.currPairList{1,i}.PnL<-0.05) %止损平仓         
                    obj.cutLossCounter(x1, x2) =obj.cutLossCounter(x1, x2)+ 1;
                    obj.cutLossRecord(x1, x2) =20;%20日内不开此pair %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    sign=true;                  
                end
                
                if (currentVal(x1, x2)<1)&&(obj.currPairList{1,i}.PnL>-0.05)% 协助不满足，平仓
                    sign = true;
                    obj.cutLossRecord(x1, x2) =20;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    obj.noValidation(x1, x2) =obj.noValidation(x1, x2)+ 1;
                end
                
                if ( currentZscore(x1,x2)*obj.currPairList{1,i}.openZScore<0 )&&(currentVal(x1, x2)>0)%止盈            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%;
                    obj.stopWinCounter(x1, x2) = obj.stopWinCounter(x1, x2)+ 1;
                    sign=true;
                end
                
                if sign==true % close the position
                    if (obj.currPairList{1,i}.PnL<0)
                        obj.lossCounter(x1, x2) =obj.lossCounter(x1, x2)+ 1;
                    else 
                        obj.winCounter(x1, x2) =obj.winCounter(x1, x2)+ 1;
                    end
                    
                    obj.existPair(x1,x2)=0; %平仓后把这个位置设定为0
                    stock1=obj.currPairList{1,i}.stock1;
                    stock2=obj.currPairList{1,i}.stock2;
                    windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(stock1);
                    windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(stock2);
                    
                    if obj.currPairList{1,i}.stock1Position<0
                        longwindTicker{length(longwindTicker)+1} = windTickers1{1};
                        longQuant = [longQuant,0];%平仓时把目标仓位设定为0
                    else
                        shortwindTicker{length(shortwindTicker)+1} = windTickers1{1};
                        shortQuant = [shortQuant,0];
                    end

                    if obj.currPairList{1,i}.stock2Position<0
                        longwindTicker{length(longwindTicker)+1} = windTickers2{1};
                        longQuant = [longQuant,0];
                    else
                        shortwindTicker{length(shortwindTicker)+1} = windTickers2{1};
                        shortQuant = [shortQuant,0];
                    end        
               else
               newList{1,length(newList)+1} =  obj.currPairList{1,i}; %如果没有平仓，则记录下来
               end            
           end
           obj.currPairList=newList;   
            buyOrderList.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            buyOrderList.account = obj.accounts('stockAccount');
            buyOrderList.price = obj.orderPriceType;
            buyOrderList.assetCode = longwindTicker;
            buyOrderList.quantity = longQuant;

            sellOrderList.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            sellOrderList.account = obj.accounts('stockAccount');
            sellOrderList.price = obj.orderPriceType;
            sellOrderList.assetCode =  shortwindTicker;
            sellOrderList.quantity = shortQuant;           
        end
        
        %% update the PnL of each stock pair portfolio in CurrPairList, 
        % It compare the price and position between the currDate and the OpenDate.
        function  autoupdateCurrPairListPnL(obj,currDate)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate ) ;
            for i=1:length(obj.currPairList)
                opendateLoc = find([obj.signals.dateList{:,1}]== obj.currPairList{1,i}.openDate) ;
                stock1=obj.currPairList{1,i}.stock1;
                stock2=obj.currPairList{1,i}.stock2;      
                stockPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, stock1);
                stockPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, stock2);
                originPrice1 = aggregatedDataStruct.stock.properties.open(opendateLoc, stock1);
                originPrice2 = aggregatedDataStruct.stock.properties.open(opendateLoc, stock2);
                obj.currPairList{1,i}.PnL=((stockPrice1-originPrice1)*obj.currPairList{1,i}.stock1Position+(stockPrice2-originPrice2)*obj.currPairList{1,i}.stock2Position)/(abs(originPrice1*obj.currPairList{1,i}.stock1Position)+abs(originPrice2*obj.currPairList{1,i}.stock2Position));
            end
            
        end  
       



        % Writer : Li Fangwen 
        % Date: 2020/06/06
        % 第二次修改后结果
        % code review：沈廷威
        %%

        function  [buyOrderList,sellOrderList] = updateCurrPairList(obj,currDate)
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
             % 分别找到expectedReturn，validity，zscore和beta在propertyNameList中对应的索引
            returnIndex = find(ismember(obj.signals.propertyNameList, 'expectedReturn'));
            validityIndex = find(ismember(obj.signals.propertyNameList, 'validity'));
            zscoreIndex = find(ismember(obj.signals.propertyNameList, 'zScore'));
            betaIndex = find(ismember(obj.signals.propertyNameList, 'beta'));
            alphaIndex = find(ismember(obj.signals.propertyNameList, 'alpha'));
            
            % 分别找到不同pair 对应的expectedReturn，validity，zscore，返回的结果都是的二维矩阵
            currentExpect = obj.signals.signalParameters(:,:,end,1,1,returnIndex);
            currentVal = obj.signals.signalParameters(:,:,end,1,1,validityIndex);
            currentZscore =  obj.signals.signalParameters(:,:,end,1,1,zscoreIndex);     
 
            %因为没有通过检验pair对应的结果都是0，这里我们用每个pair的validity，乘是否zscore大于2的逻辑判断，得到符合标准的交易pair，
            %然后这个矩阵乘以expectReturn，得到满足交易标准的pair的expectReturn
            avaliableExpect = currentVal.*currentExpect.*((currentZscore>2)+(currentZscore<-2)).*(~obj.existPair ).*(obj.cutLossRecord<0);%.*tril(currentExpect);%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            listLongth = length(obj.currPairList);
            waitLong={};
            %这部分的算法思想是从大到小找avaliableExpect中最大的10个，和currPairList进行比较看是否加入。每次都找最大的一个，比较计算完成后，把他的expectreturn变成0，防止下次再次被选到。
            for i= 1:10
                maxData = max(max(avaliableExpect)); 
                [x,y] = find(avaliableExpect== maxData);%x,y是对应的最大expectReturn的pair
                % 沈廷威2020/06/04:你这里每次循环拿到的x,y是同一个吧，有点奇怪
                % 李方闻2020/06/06:已经修改，之前忘了把找过的pair的expectreturn转化为零，已修改        
                if maxData>0
                    stock1 = obj.signals.stockLocation(x);
                    stock2 =obj.signals.stockLocation(y);%得到股票在数据库中的索引

                    %这里目前并不是真的头寸，只是保存了根据zscore判断的买卖方向，zscore大于0，做空，zscore小于0，做多
                    stock1Position = -obj.signals.signalParameters(x,y,end,1,1,zscoreIndex)/abs(obj.signals.signalParameters(x,y,end,1,1,zscoreIndex));
                    stock2Position = obj.signals.signalParameters(x,y,end,1,1,betaIndex)/abs(obj.signals.signalParameters(x,y,end,1,1,betaIndex))*...
                        obj.signals.signalParameters(x,y,end,1,1,zscoreIndex)/abs(obj.signals.signalParameters(x,y,end,1,1,zscoreIndex)); 

                    openCost = 0;%这里先不计算，之后再计算
                    openZScore = obj.signals.signalParameters(x,y,end,1,1,zscoreIndex);
                    PnL = 0;
                    openDate = obj.signals.dateList{dateLoc+1,1};%第二天开盘开仓
                    beta = obj.signals.signalParameters(x,y,end,1,1,betaIndex);
                    alpha = obj.signals.signalParameters(x,y,end,1,1,alphaIndex);
                    
                    newStruct = struct('stock1',stock1,'stock2',stock2,'stock1Position',stock1Position,'stock2Position',...
                    stock2Position,'openCost',openCost,'openZScore',openZScore,'PnL',PnL,'openDate',openDate,'expectReturn',maxData, 'beta',beta,'alpha',alpha );
                    obj.orderSort();%先排序，再比较，expectReturn从小到大排列
                    % 沈廷威2020/06/04:这个语法不太对啊，orderSort()只能由这个类的对象来调用，不能用currPairList直接调用，他就是一个成员变量，一个cell，应该是obj.orderSort()吧
                    % 李方闻2020/06/06:已经按照提示修改
                    
                    if listLongth <10%如果currPairList长度小于10，直接开仓购买组合
                        waitLong{1,length(waitLong)+1} = newStruct;%用来存放将要open的pair，这里只是记下，还没有开
                        listLongth = listLongth +1;
                    else
                        if newStruct.expectReturn > obj.currPairList{1,1}.expectReturn
                            [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.closePair(obj.currPairList{1,1},longwindTicker,longQuant,shortwindTicker,shortQuant,currDate);
                            obj.exchangeStopCounter(x,y) = obj.exchangeStopCounter(x,y)+1;
                            waitLong{1,length(waitLong)+1} = newStruct;%用来存放将要open的pair
                            %因为这个时候listlongth=10，不需要增加listLongth,仅仅是替换
                        end
                    end
                    avaliableExpect(x,:) = 0;
                    avaliableExpect(:,y) = 0;%一天内同一的股票只开一次
                else
                    break;
                end
            end
            % 这个时候currPair里面把需要close的pair都close了，但是需要open的pair还没有加入
           % everyCash = 0.7*cashAvailable/(10-length(obj.currPairList));%每份投资可用资金%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            everyCash = 0.8*obj.calNetWorth(currDate)/10;
            
            for i = 1:length(waitLong)
                 [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.openPair(waitLong{1,i},longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,everyCash);%开仓操作
            end
                   
            buyOrderList.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            buyOrderList.account = obj.accounts('stockAccount');
            buyOrderList.price = obj.orderPriceType;
            buyOrderList.assetCode = longwindTicker;
            buyOrderList.quantity = longQuant;

            sellOrderList.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            sellOrderList.account = obj.accounts('stockAccount');
            sellOrderList.price = obj.orderPriceType;
            sellOrderList.assetCode = shortwindTicker;
            sellOrderList.quantity = shortQuant;

        end

   %%
        function orderSort(obj)
            len = length(obj.currPairList);
            if len>2
                for i = 1:len
                    for j =1:len-1
                        if obj.currPairList{1,j}.expectReturn > obj.currPairList{1,j+1}.expectReturn
                             % 沈廷威2020/06/04:你这边是想做冒泡排序吧，但是我不是很明白currPairList{1,j}调用的是啥，按照设计，应该只需要一个下标可以了
                             % 李方闻2020/06/06:系统默认是一维向量，这里用一个和两个都一样，习惯用两个
                            tools = obj.currPairList{1,j+1};
                            obj.currPairList{1,j+1} = obj.currPairList{1,j};
                            obj.currPairList{1,j} = tools;
                        end
                    end
                end
            end
        end

%%
        function  [longwindTicker,longQuant,shortwindTicker,shortQuant] = openPair(obj,newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,everyCash)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
            x1 = find(ismember(obj.signals.stockLocation, newStruct.stock1));
            x2 = find(ismember(obj.signals.stockLocation, newStruct.stock2));
            obj.openCounter(x1,x2)=obj.openCounter(x1,x2)+1;
            obj.existPair(x1,x2)=1;
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock2);%wind股票代码

            fwdPrice1 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock1);
            fwdPrice2 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock2);%复权价格，用来决定资金分配

            realPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock1);
            realPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock2);%用真实股价价格用来决定真实头寸
            % 沈廷威2020/06/04:这一步别这么干，算是调用未来数据了。还是close(dateLoc，newStruct.stock2)吧 
            % 李方闻2020/06/06:已经修改

            cashFor1 = (1*fwdPrice1)/(1*fwdPrice1+abs(newStruct.beta)*fwdPrice2)*everyCash;%计算出资金分配,比例为1：beta
            cashFor2 = (abs(newStruct.beta)*fwdPrice2)/(1*fwdPrice1+abs(newStruct.beta)*fwdPrice2)*everyCash;

            costPrice1 = aggregatedDataStruct.stock.properties.open(dateLoc+1, newStruct.stock1);
            costPrice2 = aggregatedDataStruct.stock.properties.open(dateLoc+1, newStruct.stock2);%用第二天的开盘价格来计算交易成本
            realstock1Position = floor(cashFor1/costPrice1/100)*100*newStruct.stock1Position;
            realstock2Position = floor(cashFor2/costPrice2/100)*100*newStruct.stock2Position;%交易完成后的头寸

            newStruct.stock1Position = floor(cashFor1/realPrice1/100)*100*newStruct.stock1Position;
            newStruct.stock2Position = floor(cashFor2/realPrice2/100)*100*newStruct.stock2Position;%订单头寸
            % 沈廷威2020/06/04:这部分涉及到未来数据，并作为交易指导，不允许 
            % 李方闻2020/06/06:已经修改


            newStruct.openCost = (abs(realstock1Position)*costPrice1+abs(realstock2Position)*costPrice2)*2/10000;%手续费设定为万分之二
            % 沈廷威2020/06/04:这部分虽然涉及到未来数据，但并不作为交易指导，仅仅作为记录，不提倡，但可以允许 
            % 李方闻2020/06/06:已经修改
            % 沈廷威2020/06/05:这部分照你现在的修改方式就不是真实的openCost了，要不你就提前拿一下明天open的价格，要不当日就先置为0，在第二天再添加
            % 李方闻2020/06/06:已经修改为用开盘价计算的cost

            if newStruct.stock1Position>0
                longwindTicker{length(longwindTicker)+1} = windTickers1{1};
                longQuant = [longQuant, newStruct.stock1Position];
            else
                shortwindTicker{length(shortwindTicker)+1} = windTickers1{1};
                shortQuant = [shortQuant,-newStruct.stock1Position]; %这里都要保存成正数

            end

            if newStruct.stock2Position>0
                longwindTicker{length(longwindTicker)+1} = windTickers2{1};
                longQuant = [longQuant, newStruct.stock2Position];
            else
                shortwindTicker{length(shortwindTicker)+1} = windTickers2{1};
                shortQuant = [shortQuant,-newStruct.stock2Position];

            end

            obj.currPairList{1,length(obj.currPairList)+1} = newStruct;
        end


%%
        function  [longwindTicker,longQuant,shortwindTicker,shortQuant] = closePair(obj,closeStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate)
             x1 = find(ismember(obj.signals.stockLocation, closeStruct.stock1));
             x2 = find(ismember(obj.signals.stockLocation, closeStruct.stock2));
             obj.existPair(x1,x2)=0;
             aggregatedDataStruct = obj.marketData.aggregatedDataStruct;

            % 沈廷威2020/06/05:每次平仓时都要对平仓计数器winCounter或lossCounter进行+1操作，请判断决定平仓时，第二天的卖出价格相对于开仓成本到底是收益还是损失。此处仅为统计使用，故可使用未来数据
            % 这部分可以按照ppt中显示过的，新增一个cell对象，对在每次平仓时仅存储平仓的股票，开仓日期，平仓日期，平仓原因等信息，后续集中对这个数据进行统计分析。可细化。
            % 李方闻2020/06/06:已经修改，细化部分在可能需要之后和前半部分同学协商共同解决
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock2);%得到wind股票代码

            obj.currPairList = {obj.currPairList{2:end}} ; %删除第一个
            
            if closeStruct.PnL>0
                obj.stopWinCounter(x1,x2) =obj.stopWinCounter(x1,x2)+1;
            else 
                obj.cutLossCounter(x1,x2) =obj.cutLossCounter(x1,x2)+1;
            end
            
            if closeStruct.stock1Position<0
                longwindTicker{length(longwindTicker)+1} = windTickers1{1};
                longQuant = [longQuant,0];%平仓时把目标仓位设定为0
            else
                shortwindTicker{length(shortwindTicker)+1} = windTickers1{1};
                shortQuant = [shortQuant,0];
            end

            if closeStruct.stock2Position<0
                longwindTicker{length(longwindTicker)+1} = windTickers2{1};
                longQuant = [longQuant,0];
            else
                shortwindTicker{length(shortwindTicker)+1} = windTickers2{1};
                shortQuant = [shortQuant,0];
            end
        end
     end
end
