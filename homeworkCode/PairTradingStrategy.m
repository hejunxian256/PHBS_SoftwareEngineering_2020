
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
        winCounter;
        lossCounter;
        currPairList;
    end
    
    methods
        function obj = PairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
            obj.signalInitialized = 0;
            obj.winCounter=0;
            obj.lossCounter =0;
            obj.currPairList = cell(0);
        end
    
        % update the current pairtrading list through self-update,
        % examination and profit sorting.Then generate the Orders to be
        % trade tomorrow
        function [orderList, delayList] = generateOrders(obj, currDate, ~)
            orderList = [];
            delayList = [];
            if not(obj.signalInitialized)
               obj.signals = PairTradingSignal(currDate);
               obj.signalInitialized =1;
            end
            
            obj.autoupdateCurrPairListPnL(currDate);
            [cashAvailable, buyOrderList1, sellOrderList1] = obj.examCurrPairList(currDate);
            [buyOrderList2,sellOrderList2] = obj.updateCurrPairList(currDate,cashAvailable);
            orderList = [orderList,sellOrderList1,sellOrderList2,buyOrderList1,buyOrderList2];
            delayList = [delayList, 1,1,1,1];
        end
        
        
        % close the position while certain loss is beyond the level or the pairs back to the mean.
        function [cashAvailable, buyOrderList, sellOrderList] = examCurrPairList(obj,currDate)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
            cashAvailable = obj.getCashAvailable('stockAccount');
            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            
            sign = false; %the signal whether to close the position, set it here in case the currPairList is null
            for i=1:length(obj.currPairList)
                sign=false;%the signal whether to close the position
                if (obj.currPairList{1,i}.PnL<-0.02) % the rate of profit loss                      
                    lossCounter += 1;
                    sign=true;                  
                end
                
                if abs(obj.currPairList{1,i}.openZscore)<1%when the dislocation converge to 1 zscore, then close the pair
                    winConter += 1;
                    sign=true;
                end
                
                if sign==true % close the position
                    stock1=obj.currPairList{1,i}.stock1;
                    stock2=obj.currPairList{1,i}.stock2;
                    stockPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, stock1);
                    stockPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, stock2);
                    windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(stock1);
                    windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(stock2);
                    
                    if obj.currPairList{1,i}.stock1Position<0
                        longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                        longQuant = [longQuant,0];%平仓时把目标仓位设定为0
                    else
                        shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                        shortQuant = [shortQuant,0];
                    end

                    if obj.currPairList{1,i}.stock2Position<0
                        longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                        longQuant = [longQuant,0];
                    else
                        shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                        shortQuant = [shortQuant,0];
                    end        
                    cashAvailable = cashAvailable+abs(obj.currPairList{1,i}.stock1Position*stockPrice1)*(1-2/10000)+abs(obj.currPairList{1,i}.stock2Position*stockPrice2)*(1-2/10000); 
                    obj.currPairList={obj.currPairList{1:i-1},obj.currPairList{i+1:end}};
                end
                
            end
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
        
        % update the PnL of each stock pair portfolio in CurrPairList, 
        % It compare the price and position between the currDate and the OpenDate.
        function currPairList = autoupdateCurrPairListPnL(obj,currDate)
            aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate ) ;
            for i=1:length(obj.currPairList)
                opendateLoc = find([obj.signals.timeList{:,1}]== obj.currPairList{1,i}.openDate) ;
                stock1=obj.currPairList{1,i}.stock1;
                stock2=obj.currPairList{1,i}.stock2;      
                stockPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, stock1);
                stockPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, stock2);
                originPrice1 = aggregatedDataStruct.stock.properties.close(opendateLoc, stock1);
                originPrice2 = aggregatedDataStruct.stock.properties.close(opendateLoc, stock2);
                obj.currPairList{1,i}.PnL=(stockPrice1-originPrice1)*currPairList{1,i}.stock1Position+(stockPrice2-originPrice2)*currPairList{1,i}.stock2Position/(abs(originPrice1*currPairList{1,i}.stock1Position)+abs(originPrice2*currPairList{1,i}.stock2Position));
            end
            
        end  
       



        % Writer : Li Fangwen 
        % Date: 2020/06/06
        % 第二次修改后结果
        % code review：沈廷威

        function  [buyOrderList,sellOrderList] = updateCurrPairList(obj,currDate,cashAvailable)

            %aggregatedDataStruct = obj.marketData.aggregatedDataStruct;
            % [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            dateLoc = find( [obj.signals.dateList{:,1}]== currDate );
            % 沈廷威2020/06/05:date也只有转成index形式才能用signalParameters访问到，你现在用的dataLoc是老师2000多天的index，而不是我们timeList里面的index。写法应该和使用propertyNameList类似
            % 李方闻2020/06/06:已经修改

             % 分别找到expectedReturn，validity，zscore和beta在propertyNameList中对应的索引
            returnIndex = find(ismember(obj.signals.propertyNameList, 'expectedReturn'));
            validityIndex = find(ismember(obj.signals.propertyNameList, 'validity'));
            zscoreIndex = find(ismember(obj.signals.propertyNameList, 'zScore'));
            betaIndex = find(ismember(obj.signals.propertyNameList, 'beta'));

            % 分别找到不同pair 对应的expectedReturn，validity，zscore，返回的结果都是的二维矩阵
            currentExpect = obj.signals.signalParameters(:,:,end,1,1,returnIndex);
            currentVal = obj.signals.signalParameters(:,:,end,1,1,validityIndex);
            currentZscore =  obj.signals.signalParameters(:,:,end,1,1,zscoreIndex);

            %因为没有通过检验pair对应的结果都是0，这里我们用每个pair的validity，乘是否zscore大于2的逻辑判断，乘下三角矩阵（因为一个pair其实有两个组合），得到符合标准的交易pair，
            %然后这个矩阵乘以expectReturn，得到满足交易标准的pair的expectReturn
            avaliableExpect = currentVal.*currentExpect.*(currentZscore>2||currentZscore<-2).*tril(currentExpect);
            longwindTicker={};
            longQuant = [];
            shortwindTicker = {};
            shortQuant = [];
            %这部分的算法思想是从大到小找avaliableExpect中最大的10个，和currPairList进行比较看是否加入。每次都找最大的一个，比较计算完成后，把他的expectreturn变成0，防止下次再次被选到。
            for i= 1:10
                [maxDatatool,xtool] = max(avaliableExpect);
                x = xtool(1);
                [maxData,y] = max(maxDatatool); %x,y是对应的最大expectReturn的pair
                % 沈廷威2020/06/04:你这里每次循环拿到的x,y是同一个吧，有点奇怪
                % 李方闻2020/06/06:已经修改，之前忘了把找过的pair的expectreturn转化为零，已修改
                if maxData>0
                    stock1 = x;
                    stoock2 = y;

                    %这里目前并不是真的头寸，只是保存了根据zscore判断的买卖方向，zscore大于2，做空，zscore小于-2，做多
                    stock1Position = -obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)/abs(obj.signals.signalParameters(x,y,zscoreIndex,end,1,1));
                    stock2Position = obj.signals.signalParameters(x,y,betaIndex,end,1,1)*...
                        obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)/abs(obj.signals.signalParameters(x,y,zscoreIndex,end,1,1)); 

                    openCost = 0;%这里先不计算，之后再计算
                    openZScore = obj.signals.signalParameters(x,y,zscoreIndex,end,1,1);
                    PnL = 0;
                    openDate = currDate+1;%第二天开盘开仓
                    beta = obj.signals.signalParameters(x,y,betaIndex,end,1,1);

                    newStruct = struct('stock1',stock1,'stoock2',stoock2,'stock1Position',stock1Position,'stock2Position',...
                    stock2Position,'openCost',openCost,'openZScore',openZScore,'PnL',PnL,'openDate',openDate,'expectReturn',maxData,'beta',beta);
                    obj.orderSort();%先排序，再比较，expectReturn从小到大排列
                    % 沈廷威2020/06/04:这个语法不太对啊，orderSort()只能由这个类的对象来调用，不能用currPairList直接调用，他就是一个成员变量，一个cell，应该是obj.orderSort()吧
                    % 李方闻2020/06/06:已经按照提示修改

                    if (length(currPairList)<10)%如果currPairList长度小于10，直接开仓购买组合
                        [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.openPair(newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant);

                    else
                        if newStruct.expectReturn > obj.currPairList{1,1}.expectReturn %如果新的组合expectReturn更高，则替换pair
                            [longwindTicker,longQuant,shortwindTicker,shortQuant,cashAvailable] = obj.closePair(obj.currPairList{1,1},longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable);
                            [longwindTicker,longQuant,shortwindTicker,shortQuant] = obj.openPair(newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable);
                            % 沈廷威2020/06/04:这块逻辑是不是有点问题，你下次obj.currPairList{1,1}就是你最新加入的pair了
                            % 李方闻2020/06/05:那你一直在同一个位置比较啊，参与后续比较的全是新增的pair，没有老pair了
                            % 李方闻2020/06/06:这里我每次在比较之前都进行了排序，保证最小的在第一个）
                       end
                    avaliableExpect(x,y) = 0;%把已经比较过的最大值赋值为0，防止下次再次选到
                    end    
                else
                    break;
                end

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

        function orderSort(obj)
            len = length(obj.currPairList);
            for i = 1:len
                for j =1:len-i+1
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


        function  [longwindTicker,longQuant,shortwindTicker,shortQuant] = openPair(obj,newStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable)

            [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(newStruct.stock2);%wind股票代码

            fwdPrice1 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock1);
            fwdPrice2 = aggregatedDataStruct.stock.properties.fwd_close(dateLoc, newStruct.stock2);%复权价格，用来决定资金分配

            realPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock1);
            realPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, newStruct.stock2);%用真实股价价格用来决定真实头寸
            % 沈廷威2020/06/04:这一步别这么干，算是调用未来数据了。还是close(dateLoc，newStruct.stock2)吧 
            % 李方闻2020/06/06:已经修改

            everyCash = 0.85*cashAvailable/(10-length(currPairList));%每份投资可用资金
            cashFor1 = (1*fwdPrice1)/(1*fwdPrice1+abs(newStruct.beta)*fwdPrice2)*everyCash;%计算出资金分配
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
                longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                longQuant = [longQuant,newStruct.stock1Position];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                shortQuant = [shortQuant,-newStruct.stock1Position]; %这里都要保存成正数

            end

            if newStruct.stock2Position>0
                longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                longQuant = [longQuant,newStruct.stock2Position];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                shortQuant = [shortQuant,-newStruct.stock2Position];

            end

            obj.currPairList{1,length(currPairList)+1} = newStruct;
        end



        function  [longwindTicker,longQuant,shortwindTicker,shortQuant,cashAvailable] = closePair(obj,closeStruct,longwindTicker,longQuant,shortwindTicker,shortQuant,currDate,cashAvailable)

             [~, dateLoc] = ismember(currDate, aggregatedDataStruct.sharedInformation.allDates);
            if closeStruct.Pnl>closeStruct.opencost
                obj.winCounter= obj.winCounter+1;
            else
                obj.lossCounter= obj.lossCounter+1;
            end
            % 沈廷威2020/06/05:每次平仓时都要对平仓计数器winCounter或lossCounter进行+1操作，请判断决定平仓时，第二天的卖出价格相对于开仓成本到底是收益还是损失。此处仅为统计使用，故可使用未来数据
            % 这部分可以按照ppt中显示过的，新增一个cell对象，对在每次平仓时仅存储平仓的股票，开仓日期，平仓日期，平仓原因等信息，后续集中对这个数据进行统计分析。可细化。
            % 李方闻2020/06/06:已经修改，细化部分在可能需要之后和前半部分同学协商共同解决
            windTickers1 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock1);
            windTickers2 = aggregatedDataStruct.stock.description.tickers.windTicker(closeStruct.stock2);%得到wind股票代码


            realPrice1 = aggregatedDataStruct.stock.properties.close(dateLoc, closeStruct.stock1);
            % 沈廷威2020/06/05: dataLoc非成员变量，无法直接访问，请传参或者新增成员变量。
            % 李方闻2020/06/06: 已经修改
            realPrice2 = aggregatedDataStruct.stock.properties.close(dateLoc, closeStruct.stock2);%真实价格用来计算卖出现金

            cashAvailable = cashAvailable+abs(newStruct.stock1Position)*realPrice1+abs(newStruct.stock2Position)*realPrice2*(1-2/10000);%增加可用现金
            % 沈廷威2020/06/04:这部分涉及到未来数据，并作为交易指导，不允许
            % 李方闻2020/06/06:已经修改
            obj.currPairList = obj.currPairList{2:end} ; %删除第一个

            if closeStruct.stock1Position<0
                longwindTicker{length(longwindTicker)+1,1} = windTickers1;
                longQuant = [longQuant,0];%平仓时把目标仓位设定为0
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers1;
                shortQuant = [shortQuant,0];
            end

            if closeStruct.stock2Position<0
                longwindTicker{length(longwindTicker)+1,1} = windTickers2;
                longQuant = [longQuant,0];
            else
                shortwindTicker{length(shortwindTicker)+1,1} = windTickers2;
                shortQuant = [shortQuant,0];
            end
        end
     end
end
