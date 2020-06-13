function [ parameter, accounts, author ] = configParameter(strategy, initialCapital)
if nargin < 2
    initialCapital = 5e6;
end
parameter = struct;

parameter.initCapital = initialCapital;
parameter.orderPriceType = 'close';

account = mclasses.account.StockAccount(strategy, 'stockAccount');
account.initialize(parameter.initCapital);
accounts = {account};

end

