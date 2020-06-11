
%selectSector部分由蒋英杰负责开发
% Writer : Jiang Yingjie 
% Date: 2020/06/06
% 第三次修改后结果

marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
generalData = marketData.getAggregatedDataStruct;
generalData.stock
generalData.stock.sectorClassification

for i=1:34
    SectorFilter = generalData.stock.sectorClassification.levelOne == i;
    StockLocation = find(sum(SectorFilter) > 1);
    FowardPrices = generalData.stock.properties.fwd_close(:, StockLocation);
    validStartingPoint = max(sum(isnan(FowardPrices)))+3;
    CorrelationMatrix = corr(FowardPrices(validStartingPoint:end, :));
    count=CorrelationMatrix>0.9;
    total=CorrelationMatrix>-1;
    a(i)=sum(sum(count));
    b(i)=sum(sum(count))/sum(sum(total));
end
