function orderSort(obj)
    len = length(obj.currPairList);
    for i = 1:len
        for j =1:len-i+1
            if obj.currPairList{1,j}.expectReturn > obj.currPairList{1,j+1}.expectReturn
                tools = obj.currPairList{1,j+1};
                obj.currPairList{1,j+1} = obj.currPairList{1,j};
                obj.currPairList{1,j} = tools;
            end
        end
    end
end
                