unit ChekTypes;

interface

const
  // Провайдери для карткових платежів
  CardProviders: array[0..3] of string = ('BANK', 'TAPXPHONE', 'POSCONTROL', 'TERMINAL');

type
  // Підтипи безготівкової оплати з явними значеннями (1..17)
  // Цей тип використовується як у БД (chekdb), так і в API (ReceiptWebAPI)
  TCashlessSubType = (
    cstCard              = 1,   // Картка (термінал)
    cstInternetBanking   = 2,   // Інтернет банкінг
    cstInternetAcquiring = 3,   // Інтернет еквайринг
    cstLiqPay            = 4,   // LiqPay
    cstMono              = 5,   // Mono
    cstWayForPay         = 6,   // WayForPay
    cstNovaPay           = 7,   // NovaPay
    cstEasyPay           = 8,   // EasyPay
    cstGiftCertificate   = 9,   // Подарунковий сертифікат
    cstToken             = 10,  // Талон/жетон
    cstTransferNNPP      = 11,  // Переказ через ННПП
    cstTransferPTKS      = 12,  // Переказ через ПТКС
    cstCurrentAccount    = 13,  // З поточного рахунку
    cstElectronicMoney   = 14,  // Електронні гроші
    cstDigitalMoney      = 15,  // Цифрові гроші
    cstCryptocurrency    = 16,  // Криптовалюта
    cstOtherCashless     = 17   // Інше безготівкове
  );

const
  CashlessSubTypeNames: array[1..17] of string = (
    'Картка',                          // 1
    'Інтернет банкінг',                // 2
    'Інтернет еквайринг',              // 3
    'Платіж через інтегратора LiqPay', // 4  <-- ВИПРАВЛЕНО (Наказ 601)
    'Платіж через інтегратора mono',   // 5  <-- ВИПРАВЛЕНО
    'Платіж через інтегратора WayForPay', // 6  <-- ВИПРАВЛЕНО
    'Платіж через NovaPay',            // 7  <-- ВИПРАВЛЕНО
    'Платіж через інтегратора EasyPay',// 8  <-- ВИПРАВЛЕНО
    'Подарунковий сертифікат',         // 9
    'Талон',                           // 10
    'Переказ ННПП',                    // 11
    'Переказ ПТКС',                    // 12
    'З поточного рахунку',             // 13
    'Електронні гроші',                // 14
    'Цифрові гроші',                   // 15
    'Криптовалюта',                    // 16
    'Інше безготівкове'                // 17
  );

implementation

end.
