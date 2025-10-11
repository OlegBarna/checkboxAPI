unit ReceiptWebAPI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, fpjson, jsonparser, jsonscanner, fgl,
  regexpr, dateutils, inifiles, TypInfo, Math, StrUtils;

type
  TAuthAction = (aaSave, aaClear, aaLoad);  // Новий тип для дій з авторизацією
  // Тип для операцій з готівкою
  TCashOperationType = (cotCashIn, cotCashOut);
  // Типи для знижок
  TDiscountType = (dtDiscount, dtExtraCharge);
  TDiscountMode = (dmValue, dmPercent);

  // Типи для оплати
  TPaymentType = (
  ptCash,      // Готівка
  ptCashless,  // Безготівка
  ptCard       // Картка - ДОДАЙТЕ ЦЕ ЗНАЧЕННЯ
);

  // Типи для типів чеків
  TReceiptType = (rtSell, rtReturn, rtServiceIn, rtServiceOut, rtCashWithdrawal);

  // Типи для провайдерів оплати
  TPaymentProvider = (ppBank, ppTapXPhone, ppPosControl, ppTerminal);

  // Типи статусів
  TTransactionStatus = (tsPending, tsDone, tsError);
  TReceiptStatus = (rsCreated, rsPending, rsDone, rsError,rsDelivered);

  //Log
  TLogProcedure = procedure(const AMessage: string) of object;

  // Forward-оголошення класу
  TReceiptWebAPI = class;

  // Запис для операції з готівкою
  TCashOperation = class
  public
    OperationType: TCashOperationType;
    Amount: Integer; // у копійках
    Description: string;
    destructor Destroy; override;
  end;

  TBalanceInfo = class
  public
    Initial: Integer;         // Початковий баланс (копійки)
    Balance: Integer;         // Поточний баланс (копійки)
    CashSales: Integer;       // Готівкові продажі (копійки)
    CardSales: Integer;       // Безготівкові продажі (копійки)
    DiscountsSum: Integer;    // Сума знижок (копійки)
    ExtraChargeSum: Integer;  // Сума націнок (копійки)
    CashReturns: Integer;     // Готівкові повернення (копійки)
    CardReturns: Integer;     // Безготівкові повернення (копійки)
    ServiceIn: Integer;       // Службове внесення (копійки)
    ServiceOut: Integer;      // Службова витрата (копійки)
    UpdatedAt: TDateTime;     // Час останнього оновлення
    destructor Destroy; override;
  end;

  // Запис для платежу у звіті
  TShiftPayment = class
  public
    PaymentType: string; // "CASH" або "CASHLESS"
    ProviderType: string; // "TAPXPHONE", "POSCONTROL", "TERMINAL"
    Code: Integer;
    LabelText: string;
    SellSum: Integer;
    ReturnSum: Integer;
    ServiceIn: Integer;
    ServiceOut: Integer;
    CashWithdrawal: Integer;
    CashWithdrawalCommission: Integer;
    destructor Destroy; override;
  end;

  // Запис для податку зміни (об'єднана версія)
  TShiftTax = class
  public
    Id: string;
    Code: Integer;
    LabelText: string;
    Symbol: string;
    Rate: Double;
    ExtraRate: Double;
    SellSum: Integer;
    ReturnSum: Integer;
    SalesTurnover: Integer;
    ReturnsTurnover: Integer;
    SetupDate: TDateTime;
    Included: Boolean;
    NoVat: Boolean;
    AdvancedCode: string;
    Sales: Double;
    Returns: Double;
    TaxSum: Double;          // Сума податку
    ExtraTaxSum: Double;     // Сума додаткового податку
    destructor Destroy; override;
  end;

  // Запис для звіту зміни
  TShiftReport = class
  public
    Id: string;
    Serial: Integer;
    Payments: array of TShiftPayment;
    Taxes: array of TShiftTax;
    SellReceiptsCount: Integer;
    ReturnReceiptsCount: Integer;
    CashWithdrawalReceiptsCount: Integer;
    LastReceiptId: string;
    Initial: Integer;
    Balance: Integer;
    SalesRoundUp: Integer;
    SalesRoundDown: Integer;
    ReturnsRoundUp: Integer;
    ReturnsRoundDown: Integer;
    CreatedAt: TDateTime;
    DiscountsSum: Integer;    // Сума знижок (копійки)
    ExtraChargeSum: Integer;  // Сума націнок (копійки)
    destructor Destroy; override;
  end;



  // Запис для статусу каси
  TCashRegisterStatus = class
  public
    Id: string;
    FiscalNumber: string;
    Active: Boolean;
    Number: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    LastZReportDate: TDateTime;
    ShiftStatus: string; // OPENED, CLOSED
    ShiftOpenedAt: TDateTime;
    ShiftClosedAt: TDateTime;
    CurrentShiftNumber: Integer;
    OfflineMode: Boolean;
    StayOffline: Boolean;
    IsTest: Boolean;
    destructor Destroy; override;
  end;

  // Запис для помилки API
  TAPIError = class
  public
    Code: string;
    Message: string;
    Details: string;
    Timestamp: TDateTime;
    destructor Destroy; override;
  end;

  // Запис для службової операції
  TServiceOperation = class
  public
    Id: string; // Унікальний ідентифікатор операції
    OperationType: string; // Тип операції: "SERVICE_IN" (внесення), "SERVICE_OUT" (витрата)
    Amount: Integer; // Сума операції у копійках
    Description: string; // Опис операції
    CreatedAt: TDateTime; // Дата та час створення операції
    UpdatedAt: TDateTime; // Дата та час оновлення операції
    TransactionId: string; // ID пов'язаної транзакції
    CashierId: string; // ID касира, який виконав операцію
    ShiftId: string; // ID зміни, в якій виконана операція
    FiscalNumber: string; // Фіскальний номер документа
    DocumentNumber: string; // Номер документа операції
    IsOffline: Boolean; // Чи виконана в офлайн-режимі
    OfflineId: string; // ID офлайн-операції

    destructor Destroy; override;
  end;

  // Запис для підпису
  TSignature = class
  public
    SignatureType: string; // Тип підпису: "AGENT", "CUSTOMER", "CASHIER", "SYSTEM"
    Value: string; // Значення підпису (base64, XML, JSON або інший формат)
    SignatoryName: string; // Ім'я особи, що підписала
    SignatoryTin: string; // ІПН особи, що підписала
    SignedAt: TDateTime; // Дата та час підписання
    Certificate: string; // Сертифікат електронного підпису (base64)
    CertificateThumbprint: string; // Відбиток сертифіката
    SignatureFormat: string; // Формат підпису: "XMLDSIG", "CMS", "JWS", "PDF"
    IsValid: Boolean; // Чи є підпис валідним
    ValidationDetails: string; // Деталі перевірки підпису
    RelatedDocumentId: string; // ID пов'язаного документа
    RelatedDocumentType: string; // Тип пов'язаного документа

    destructor Destroy; override;
  end;

  // Запис для податку
  TTax = class
  public
    Id: string;
    Code: Integer;
    LabelText: string;
    Symbol: string;
    Rate: Double;
    ExtraRate: Double;
    Included: Boolean;
    NoVat: Boolean;
    AdvancedCode: string;
    Value: Double;
    ExtraValue: Double;
    destructor Destroy; override;
  end;

  // Запис для товару
  TGood = class
  public
    Code: string;
    Name: string;
    Price: Integer; // у копійках
    TaxCodes: array of Integer;
    Barcode: string;
    ExciseBarcodes: array of string;
    Header: string;
    Footer: string;
    Uktzed: string;
    destructor Destroy; override;
  end;

  // Запис для знижки на товар
  TGoodDiscount = class
  public
    DiscountType: TDiscountType;
    Mode: TDiscountMode;
    Value: Double;
    TaxCode: Integer;
    TaxCodes: array of Integer;
    Name: string;
    Privilege: string;
    destructor Destroy; override;
  end;

  // Запис для позиції товару в чеку
  TGoodItem = class
  public
    Good: TGood;
    GoodId: string; // UUID v4
    Quantity: Integer; // у тисячах (1 шт = 1000)
    Sum: Integer; // сума товару у копійках
    IsReturn: Boolean;
    IsWinningsPayout: Boolean;
    Discounts: array of TGoodDiscount;
    TotalSum: Integer;
    Taxes: array of TTax;
    destructor Destroy; override;
  end;

  // Запис для доставки
  TDelivery = class
  public
    Email: string;
    Emails: array of string;
    Phone: string; // формат 380...
    destructor Destroy; override;
  end;

  // Запис для знижки на весь чек
  TReceiptDiscount = class
  public
    DiscountType: TDiscountType;
    Mode: TDiscountMode;
    Value: Double;
    TaxCode: Integer;
    TaxCodes: array of Integer;
    Name: string;
    Privilege: string;
    Sum: Integer;
    destructor Destroy; override;
  end;

  // Запис для бонусів
  TBonus = class
  public
    BonusCard: string;
    Value: Double;
    AdditionalInfo: string;
    destructor Destroy; override;
  end;


  // Запис для оплати
  TPayment = class
  public
    PaymentType: TPaymentType; // Основний тип оплати (готівка/безготівка)
    LabelText: string; // Текстове представлення типу оплати (наприклад, "Готівка", "Безготівка")
    PLabel: string; // Альтернативна текстова мітка (дублює LabelText в деяких випадках)
    Value: Integer; // Сума оплати у копійках
    Code: Integer; // Код типу оплати (числовий ідентифікатор)
    PawnshopIsReturn: Boolean; // Чи є це поверненням в ломбарді
    ProviderType: string; // Тип провайдера оплати (наприклад, "BANK", "TAPXPHONE", "POSCONTROL", "TERMINAL")
    Commission: Double; // Комісія за операцію у відсотках або грошовому вираженні
    CardMask: string; // Маска номера картки (для безготівкових оплат)
    BankName: string; // Назва банку-емітента картки
    AuthCode: string; // Код авторизації операції
    RRN: string; // Retrieval Reference Number - унікальний ідентифікатор транзакції
    PaymentSystem: string; // Платіжна система (наприклад, "VISA", "MASTERCARD")
    OwnerName: string; // Ім'я власника картки
    Terminal: string; // Ідентифікатор терміналу
    AcquirerAndSeller: string; // Назва еквайєра та продавця
    Acquiring: string; // Тип еквайрингу
    ReceiptNo: string; // Номер чека або транзакції
    SignatureRequired: Boolean; // Чи потрібен підпис клієнта
    TapxphoneTerminal: string; // Ідентифікатор терміналу TapXPhone
    CommissionValue: Integer; // Комісія у грошовому вираженні (копійки)
    Currency: string; // Валюта операції (за замовчуванням UAH)
    ExchangeRate: Double; // Курс валюти (для операцій в інших валютах)
    ForeignValue: Integer; // Сума в валюті операції
    ForeignCurrency: string; // Код валюти операції (ISO 4217)
    IsOffline: Boolean; // Чи була операція проведена в офлайн-режимі
    OfflineId: string; // Ідентифікатор офлайн-транзакції
    ProcessedAt: TDateTime; // Дата та час проведення операції
    AdditionalInfo: string; // Додаткова інформація про операцію
    ResponseCode: string; // Код відповіді банку
    Status: string; // Статус операції (наприклад, "APPROVED", "DECLINED")
    CardType: string; // Тип картки (DEBIT/CREDIT)
    IssuerCountry: string; // Країна банку-емітента
    CardBrand: string; // Бренд картки
    IsPrepaid: Boolean; // Чи є це предоплатою
    LoyaltyProgram: string; // Лояльність/бонусна програма
    LoyaltyPoints: Integer; // Накопичені бонуси
    destructor Destroy; override;
  end;

  // Запис для кастомних налаштувань
  TCustomSettings = class
  public
    HtmlGlobalHeader: string;
    HtmlGlobalFooter: string;
    HtmlBodyStyle: string;
    HtmlReceiptStyle: string;
    HtmlRulerStyle: string;
    HtmlLightBlockStyle: string;
    TextGlobalHeader: string;
    TextGlobalFooter: string;
    destructor Destroy; override;
  end;

  // Запис для чека
  TReceipt = class
  public
    Id: string; // UUID v4
    ReceiptType: TReceiptType; // Тип чека (SELL/RETURN/SERVICE_IN/SERVICE_OUT) - НОВЕ!
    CashierName: string; // Ім'я касира
    Departament: string; // Відділ
    Goods: array of TGoodItem; // Товари
    Delivery: TDelivery; // Доставка
    Discounts: array of TReceiptDiscount; // Знижки
    Bonuses: array of TBonus; // Бонуси
    Payments: array of TPayment; // Оплати
    Taxes: array of TTax; // Податки на рівні чека - НОВЕ!
    Rounding: Boolean; // Заокруглення
    Header: string; // Заголовок
    Footer: string; // Футер
    Barcode: string; // Штрих-код
    OrderId: string; // ID замовлення
    RelatedReceiptId: string; // ID пов'язаного чека
    PreviousReceiptId: string; // ID попереднього чека
    TechnicalReturn: Boolean; // Технічне повернення
    IsPawnshop: Boolean; // Чи є ломбардом
    Custom: TCustomSettings; // Кастомні налаштування
    Sum: Integer; // Сума
    TotalSum: Integer; // Загальна сума
    TotalPayment: Integer; // Загальна оплата
    TotalRest: Integer; // Загальна решта
    Rest: Integer; // Решта
    Context: string; // Контекст
    StockCode: string; // Код складу
    CurrencyExchange: string; // Обмін валюти
    ServiceCurrencyExchange: array of string; // Сервісний обмін валюти
    IsOffline: Boolean; // Офлайн-режим - НОВЕ!
    OfflineSequenceNumber: Integer; // Офлайн-послідовність - НОВЕ!
    Signatures: array of TSignature; // Підписи
    ServiceOperations: array of TServiceOperation; // Службові операції
    constructor Create;
    destructor Destroy; override;
  end;

  // Запис для транзакції
  TTransaction = class
  public
    Id: string; // ID транзакції
    TransactionType: string; // Тип транзакції
    Serial: Integer; // Серійний номер
    Status: TTransactionStatus; // Статус
    RequestSignedAt: TDateTime; // Час підписання запиту
    RequestReceivedAt: TDateTime; // Час отримання запиту
    ResponseStatus: string; // Статус відповіді
    ResponseErrorMessage: string; // Помилка відповіді
    ResponseId: string; // ID відповіді
    OfflineId: string; // Офлайн ID
    CreatedAt: TDateTime; // Час створення
    UpdatedAt: TDateTime; // Час оновлення
    OriginalDatetime: TDateTime; // Оригінальний час
    PreviousHash: string; // Попередній хеш
    Signatures: array of TSignature; // Підписи

    destructor Destroy; override;
  end;


  // Запис для балансу зміни
   TShiftBalanceData = class
   public
     Initial: Integer; // Початковий баланс (копійки)
     Balance: Integer; // Поточний баланс (копійки)
     CashSales: Integer; // Готівкові продажі (копійки)
     CardSales: Integer; // Безготівкові продажі (копійки)
     DiscountsSum: Integer; // Сума знижок (копійки)
     ExtraChargeSum: Integer; // Сума націнок (копійки)
     CashReturns: Integer; // Готівкові повернення (копійки)
     CardReturns: Integer; // Безготівкові повернення (копійки)
     ServiceIn: Integer; // Службове внесення (копійки)
     ServiceOut: Integer; // Службова витрата (копійки)
     SalesRoundUp: Integer; // Заокруглення продажів вгору
     SalesRoundDown: Integer; // Заокруглення продажів вниз
     ReturnsRoundUp: Integer; // Заокруглення повернень вгору
     ReturnsRoundDown: Integer; // Заокруглення повернень вниз
     UpdatedAt: TDateTime; // Час оновлення
     SellReceiptsCount: Integer; // Кількість чеків продажу
     ReturnReceiptsCount: Integer; // Кількість чеків повернення
     CashWithdrawalReceiptsCount: Integer; // Кількість чеків витрати готівки
     LastReceiptId: string; // ID останнього чека
     Taxes: array of TShiftTax; // Податки
     Payments: array of TShiftPayment; // Платежі
     ShiftId: string; // ID зміни
     ShiftSerial: Integer; // Серійний номер зміни
     ShiftStatus: string; // Статус зміни
     ShiftOpenedAt: TDateTime; // Час відкриття зміни
     ShiftClosedAt: TDateTime; // Час закриття зміни
     CashRegisterId: string; // ID касового апарату
     CashRegisterFiscalNumber: string; // Фіскальний номер каси
     CashRegisterNumber: string; // Номер каси
     CashierId: string; // ID касира
     CashierName: string; // Ім'я касира
     CashierNIN: string; // ІПН касира
     ServiceOperations: array of TServiceOperation; // Службові операції

     destructor Destroy; override;
   end;


   TCashRegister = class  // Простий клас для списку кас (не Status)
   public
     Id: string;
     FiscalNumber: string;
     Active: Boolean;
     Number: string;  // Або Title, якщо в API
     CreatedAt: TDateTime;
     UpdatedAt: TDateTime;
     OfflineMode: Boolean;
     StayOffline: Boolean;
     IsTest: Boolean;  // Додайте, парсити або обчислювати
     Address: string;  // З branch.address
     destructor Destroy; override;
   end;

   TCashRegisterArray = array of TCashRegister;  // Динамічний масив

   // Запис для касира
   TCashier = class
   public
     Id: string; // ID касира
     FullName: string; // Повне ім'я
     Nin: string; // ІПН
     KeyId: string; // ID ключа
     SignatureType: string; // Тип підпису
     CertificateEnd: TDateTime; // Закінчення сертифіката
     Blocked: Boolean; // Заблокований
     CreatedAt: TDateTime; // Час створення
     UpdatedAt: TDateTime; // Час оновлення
     Signatures: array of TSignature; // Підписи

     destructor Destroy; override;
   end;

   // Запис для зміни
   TShift = class
   public
     Id: string; // ID зміни
     Serial: Integer; // Серійний номер
     Status: string; // Статус
     ZReport: string; // Z-звіт
     OpenedAt: TDateTime; // Час відкриття
     ClosedAt: TDateTime; // Час закриття
     InitialTransaction: TTransaction; // Початкова транзакція
     ClosingTransaction: TTransaction; // Закриваюча транзакція
     CreatedAt: TDateTime; // Час створення
     UpdatedAt: TDateTime; // Час оновлення
     Balance: TShiftBalanceData; // Баланс
     Taxes: array of TShiftTax; // Податки
     EmergencyClose: Boolean; // Аварійне закриття
     EmergencyCloseDetails: string; // Деталі аварійного закриття
     CashRegister: TCashRegister; // Касовий апарат
     Cashier: TCashier; // Касир
     Signatures: array of TSignature; // Підписи
     ServiceOperations: array of TServiceOperation; // Службові операції

     destructor Destroy; override;
   end;

   TReceiptCustomFields = class
   public
     ReceiptNumber : string;
     CustomerName : string;
     CustomerAddress : string;
     ContractNumber : string;
     ContractDate : TDateTime;
     DocumentNumber : string;
     DocumentDate : TDateTime;
     AdditionalInfo : string;
     PaymentDetails : string;
     CashierTitle : string;
     PreparedBy : string;
     CashWithdrawalPurpose : string;
     CashWithdrawalRecipient : string;
     CashWithdrawalPayer : string;
     CashWithdrawalSource : string;
     CashWithdrawalOrderNumber : string;
     CashWithdrawalOrderDate : TDateTime;
     CashWithdrawalBudgetCode : string;
     CashWithdrawalBudgetPeriod : string;
     CashWithdrawalDocumentType : string;
     CashWithdrawalTaxId : string;
     CashWithdrawalTaxIdSeries : string;
     CashWithdrawalTaxIdNumber : string;
     CashWithdrawalTaxIdIssuedBy : string;
     CashWithdrawalTaxIdIssuedAt : TDateTime;
     CashWithdrawalRepresentative : string;
     CashWithdrawalRepresentativeTaxId : string;
     CashWithdrawalRepresentativeTaxIdSeries : string;
     CashWithdrawalRepresentativeTaxIdNumber : string;
     CashWithdrawalRepresentativeTaxIdIssuedBy : string;
     CashWithdrawalRepresentativeTaxIdIssuedAt : TDateTime;
     CashWithdrawalRepresentativeDocument : string;
     CashWithdrawalRepresentativeDocumentSeries : string;
     CashWithdrawalRepresentativeDocumentNumber : string;
     CashWithdrawalRepresentativeDocumentIssuedBy : string;
     CashWithdrawalRepresentativeDocumentIssuedAt : TDateTime;
     destructor Destroy; override;
   end;

  // Запис для відповіді сервера
  TReceiptResponse = class
  public
    Id: string; // ID чека
    ReceiptType: string; // Тип чека
    RType: string; // Тип (альтернативний)
    Transaction: TTransaction; // Транзакція
    Serial: Integer; // Серійний номер
    Status: TReceiptStatus; // Статус
    Goods: array of TGoodItem; // Товари
    Payments: array of TPayment; // Оплати
    TotalSum: Integer; // Загальна сума
    Sum: Integer; // Сума
    TotalPayment: Integer; // Загальна оплата
    TotalRest: Integer; // Загальна решта
    Rest: Integer; // Решта
    RoundSum: Integer; // Сума заокруглення
    FiscalCode: string; // Фіскальний код
    FiscalDate: TDateTime; // Фіскальна дата
    DeliveredAt: TDateTime; // Час доставки
    CreatedAt: TDateTime; // Час створення
    UpdatedAt: TDateTime; // Час оновлення
    Taxes: array of TTax; // Податки
    Discounts: array of TReceiptDiscount; // Знижки
    OrderId: string; // ID замовлення
    Header: string; // Заголовок
    Footer: string; // Футер
    Barcode: string; // Штрих-код
    Custom: TCustomSettings; // Кастомні налаштування
    Context: string; // Контекст
    IsCreatedOffline: Boolean; // Створено офлайн
    IsSentDps: Boolean; // Відправлено до ДПС
    SentDpsAt: TDateTime; // Час відправки до ДПС
    TaxUrl: string; // URL податкової
    RelatedReceiptId: string; // ID пов'язаного чека
    TechnicalReturn: Boolean; // Технічне повернення
    StockCode: string; // Код складу
    CurrencyExchange: string; // Обмін валюти
    ServiceCurrencyExchange: array of string; // Сервісний обмін валюти
    Shift: TShift; // Зміна
    Cashier: TCashier; // Касир
    CashRegister: TCashRegister; // Касовий апарат
    CustomFields: TReceiptCustomFields; // Кастомні поля
    ControlNumber: string; // Контрольний номер
    OfflineSequenceNumber: Integer; // Офлайн-послідовність
    IsOffline: Boolean; // Офлайн-режим
    FiscalTimestamp: TDateTime; // Фіскальний час
    ProcessingStatus: string; // Статус обробки
    Signatures: array of TSignature; // Підписи
    ServiceOperations: array of TServiceOperation; // Службові операції
    ErrorMessage: string; // ⚠️ НОВЕ: Для зберігання 'message' з помилок сервера
    function ParseFromJSON(const JSONString: string; AWebAPI: TReceiptWebAPI): Boolean;
    function ParseServiceOperationsFromJSON(ServiceArray: TJSONArray; AWebAPI: TReceiptWebAPI): Boolean;

    destructor Destroy; override;
  end;

  // Запис для статусу зміни
  TShiftStatus = class
  public
    Id: string; // ID зміни
    Status: string; // Статус: "OPENED", "CLOSED"
    Serial: Integer; // Серійний номер
    ZReport: string; // Z-звіт
    OpenedAt: TDateTime; // Час відкриття
    ClosedAt: TDateTime; // Час закриття
    InitialTransactionId: string; // ID початкової транзакції
    ClosingTransactionId: string; // ID закриваючої транзакції
    CreatedAt: TDateTime; // Час створення
    UpdatedAt: TDateTime; // Час оновлення
    EmergencyClose: Boolean; // Аварійне закриття
    EmergencyCloseDetails: string; // Деталі аварійного закриття
    CashRegisterId: string; // ID касового апарату
    CashierId: string; // ID касира
    Balance: TBalanceInfo; // Баланс
    Signatures: array of TSignature; // Підписи
    ServiceOperations: array of TServiceOperation; // Службові операції

    destructor Destroy; override;
  end;


  // Тип для зберігання інформації про авторизацію
  TAuthInfo = class
  public
    Token: string;
    TokenType: string;
    RefreshToken: string;
    ExpiresAt: TDateTime;
    constructor Create;
    destructor Destroy; override;
  end;


  // Клас для роботи з Checkbox WebAPI
  TReceiptWebAPI = class
  private
    FBaseURL: string;
    FClientName: string;
    FClientVersion: string;
    FLicenseKey: string;
    FLastError: string; // Додаємо поле для помилок
    FReceiptsDirectory: string;
    FTempDirectory: string;
    //FAuthToken: string; // Для зворотньої сумісності
    FAuthInfo: TAuthInfo;
    FUsername: string;
    FPassword: string;
    FCurrentShiftId: string;
    FCurrentCashRegisterId: string;
    FLastShiftReport: TShiftReport;
    FBalanceData: TShiftBalanceData;
    FLogProcedure: TLogProcedure;
    FCurrentBalance: Integer;
    FLastBalanceUpdate: TDateTime;
    FBalanceUpdateInterval: Integer;

    //FAccessToken: string; // Токен авторизації
    //FTokenExpiration: TDateTime; // Час закінчення дії токена
    FLastCashRegisterUpdate: TDateTime; // Час останнього оновлення кас
    FLastCashRegisterResponse: string; // Кешована відповідь
    //function ValidateAPIState: Boolean;

    function DiscountTypeToString(ADiscountType: TDiscountType): string;
    function DiscountModeToString(ADiscountMode: TDiscountMode): string;
    function PaymentTypeToString(APaymentType: TPaymentType): string;

    function PaymentProviderToString(AProvider: TPaymentProvider): string;
    function StringToTransactionStatus(const Status: string): TTransactionStatus;
    function StringToReceiptStatus(const Status: string): TReceiptStatus;
    function ParseDateTime(const DateTimeStr: string): TDateTime;
    function BoolToStr(Value: Boolean; UseBoolStrs: Boolean = False): string;
    procedure Log(const AMessage: string);
    function ExecuteCurlCommand(const ACommand: string; const AProcedureName, AEndpoint: string; out AResponse: string): Boolean;
    function CheckResponseForErrors(const AResponse: string): Boolean;
    function BuildJsonData(AReceipt: TReceipt): TJSONObject;
    function BuildAuthJsonData: TJSONObject;
    function BuildOpenShiftJsonData(const AShiftId, AFiscalCode, AFiscalDate: string): TJSONObject;
    function BuildCloseShiftJsonData(ASkipClientNameCheck: Boolean; AReport: TShiftReport;
               const AFiscalCode, AFiscalDate: string): TJSONObject;
    function BuildGoOnlineJsonData: TJSONObject;
    function BuildGoOfflineJsonData: TJSONObject;

    function ParseSignatureFromJSON(SignatureObj: TJSONObject): TSignature;

    function ParseAuthResponse(const JSONString: string): Boolean;
    function ParsePinCodeAuthResponse(const JSONString: string): Boolean;
    function ParseCashRegisterStatus(const JSONString: string; out ACashRegisterStatus: TCashRegisterStatus): Boolean;
    function ParseShiftStatus(const JSONString: string; out AShiftStatus: TShiftStatus): Boolean;
    function ParseShiftReport(const JSONString: string; out AShiftReport: TShiftReport): Boolean;
    function ParseAPIError(const JSONString: string; out AError: TAPIError): Boolean;
    function CashOperationTypeToString(AOperationType: TCashOperationType): string;
    function BuildCashOperationJsonData(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string): TJSONObject;
    function CashOperationCurl(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function TryAlternativeCashOperation(AOperationType: TCashOperationType;
       AAmount: Integer; ADescription: string; out AResponse: string;
          out AReceiptResponse: TReceiptResponse): Boolean;
    function FormatBalanceInfo(Balance: TBalanceInfo): string;
    function GetAuthToken: string;
    procedure SetAuthToken(const Value: string);
    function BuildJsonDataCorrected(AReceipt: TReceipt): TJSONObject;
    function IsNetworkError(const AResponse: string): Boolean;


    //function GetTempDirectory: string;

  public
    constructor Create(ABaseURL, AClientName, AClientVersion, ALicenseKey: string;
      ALogProcedure: TLogProcedure = nil);
    destructor Destroy; override;

    property BaseURL: string read FBaseURL write FBaseURL;
    property ClientName: string read FClientName write FClientName;
    property ClientVersion: string read FClientVersion write FClientVersion;
    property AuthToken: string read GetAuthToken write SetAuthToken;
    property Username: string read FUsername;
    property Password: string read FPassword;
    property LicenseKey: string read FLicenseKey write FLicenseKey;
    property CurrentShiftId: string read FCurrentShiftId write FCurrentShiftId;
    property CurrentCashRegisterId: string read FCurrentCashRegisterId write FCurrentCashRegisterId;
    property CurrentBalance: Integer read FCurrentBalance write FCurrentBalance;
    property BalanceUpdateInterval: Integer read FBalanceUpdateInterval write FBalanceUpdateInterval;
    property LastError: string read FLastError;
    property ReceiptsDirectory: string read FReceiptsDirectory write FReceiptsDirectory;
    property TempDirectory: string read FTempDirectory write FTempDirectory;

    //function GetReceiptsDirectory: string;

    function GenerateUUID: string;
    function IsValidUUID(const UUID: string): Boolean;

    function LoginCurl(AUsername, APassword: string; out AResponse: string): Boolean;
    function PinCodeLoginCurl(APinCode: string; out AResponse: string): Boolean;
    function LogoutCurl(out AResponse: string): Boolean;
    function IsTokenValid: Boolean;
    procedure SetLogProcedure(ALogProcedure: TLogProcedure);
    function GetCurrentCashierInfo(var Response: string): Boolean;

    function SendReceiptCurl(AReceipt: TReceipt; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function GetReceiptEndpoint(AReceiptType: TReceiptType): string;
    procedure ParseAPIError(const AResponse: string; out AErrorDescription: string);

    function GetReceiptStatusCurl(const AReceiptId: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function CancelReceiptCurl(const AReceiptId, AReason: string; out AResponse: string): Boolean;
    function GetCashRegisterStatusCurl(const ACashRegisterId: string; out AResponse: string; out ACashRegisterStatus: TCashRegisterStatus): Boolean;
    function GetCashRegistersListCurl(out AResponse: string; out ACashRegisters: TCashRegisterArray): Boolean;
    function FindCashRegisterByFiscalNumber(const AFiscalNumber: string;
               out ACashRegisterId: string; out AResponse: string): Boolean;
    function InitializeFirstCashRegister(out AResponse: string): Boolean;
    function InitializeCashRegister(const AFiscalNumber: string; out AResponse: string): Boolean;
    function CheckCashRegisterMode(const ACashRegisterId: string; out AResponse: string): Boolean;
    function GoOnlineCurl(out AResponse: string): Boolean;
    function WaitForOnlineMode(out AResponse: string;ATimeoutSec: Integer = 300): Boolean;
    function GoOfflineCurl(out AResponse: string): Boolean;
    function WaitForOfflineMode(out AResponse: string;ATimeoutSec: Integer = 300): Boolean;
    function OpenShiftCurl(const AShiftId, AFiscalCode, AFiscalDate: string;
      out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function OpenShiftWithRecovery(const AShiftId, AFiscalCode, AFiscalDate: string;
       out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function CloseShiftSimpleCurl(const AShiftId: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function CloseShiftWithReportCurl(ASkipClientNameCheck: Boolean; AReport: TShiftReport;
      const AFiscalCode, AFiscalDate: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function ForceCloseShift(out AResponse: string): Boolean;
    function GetShiftStatusCurl(const AShiftId: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function WaitForShiftStatus(const AShiftId: string;
      const ATargetStatus: string; out AResponse: string;
      out AShiftStatus: TShiftStatus; ATimeoutSec: Integer = 60): Boolean;
    function CheckCurrentShift(out AResponse: string;
      out AShiftStatus: TShiftStatus): Boolean;
    function GetCurrentShiftIdCurl(out AResponse: string): string;
    function RecoverShift(out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
    function GetZReportCurl(const AShiftId: string; out AResponse: string): Boolean;
    function GetReportText(const AReportId: string; out AResponse: string): Boolean;
    function CloseCurrentShiftCurl(out AResponse: string;out AShiftStatus: TShiftStatus): Boolean;
    function GetShiftReportCurl(const AShiftId: string; out AResponse: string; out AShiftReport: TShiftReport): Boolean;
    function GetShiftBalance(out ABalance: Integer; out AResponse: string): Boolean;
    function GetShiftBalanceDirect(out ABalance: Integer; out AResponse: string): Boolean;
    procedure SaveBalanceData(JsonData: TJSONObject);
    function GetBalanceData: TShiftBalanceData;
    function GetShiftZReportCurl(const AShiftId: string; out AResponse: string; out AShiftReport: TShiftReport): Boolean;
    function GetShiftXReportCurl(const AShiftId: string; out AResponse: string; out AShiftReport: TShiftReport): Boolean;
    function GetCurrentBalance(out AResponse: string): Integer;
    function ForceBalanceUpdate(out AResponse: string): boolean;
    procedure LoadShiftIdFromFile;
    procedure SaveShiftIdToFile;
    procedure SaveShiftToFile(const AShiftId: string);
    function LoadShiftFromFile: string;
    function GetCashierInfoCurl(out AResponse: string; out ACashier: TCashier): Boolean;
    function CheckConnectivityCurl(out AResponse: string): Boolean;
    function GetFiscalMemoryStatusCurl(out AResponse: string): Boolean;
    function GetPrinterStatusCurl(out AResponse: string): Boolean;
    function SaveOfflineReceipt(AReceipt: TReceipt): Boolean;
    function ProcessOfflineReceipts: Boolean;
    function GetOfflineQueueStatus: Integer;
    function CashInCurl(AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function CashOutCurl(AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function CreateCashOperation(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string): TCashOperation;
    function CashIncome(AAmount: Integer; ADescription: string;
             out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function CashOutcome(AAmount: Integer; ADescription: string;
             out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function ServiceCashOperation(AOperationType: string; AAmount: Integer;
              ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
    function ExtractBalanceFromShiftStatus(const JSONString: string): Integer;
    function CreateGood(ACode, AName: string; APrice: Integer): TGood;
    function CreateGoodItem(AGood: TGood; AQuantity: Integer): TGoodItem;
    function CreatePayment(APaymentType: TPaymentType; AValue: Integer): TPayment;
    function CreateDelivery(AEmail, APhone: string): TDelivery;
    function CreateServiceOperation(AOperationType: string; AAmount: Integer; ADescription: string): TServiceOperation;
    function CreateSignature(ASignatureType, AValue: string): TSignature;

    function StringToReceiptType(const ATypeStr: string): TReceiptType;
    function ReceiptTypeToString(AReceiptType: TReceiptType): string;
    function CreateTaxByGroup(const ATaxGroup: string): TTax;
    function CalculateTaxValue(APrice: Integer; ATaxRate: Double): Double;
    function ValidateReceiptStructure(AReceipt: TReceipt; out AError: string): Boolean;

    procedure HandleAuthState(Action: TAuthAction);

    function CreateCardPayment(AValue: Integer;
       AProvider: TPaymentProvider; ACardMask, AAuthCode, ARRN: string): TPayment;

    

    // Нові методи для візуалізації через curl
    function GetReceiptHTML(const AReceiptId: string; out AHTMLContent: string): Boolean;
    function GetReceiptPNG(const AReceiptId: string; out AFileName: string;
      const AWidth: Integer = 0; const APaperWidth: Integer = 0;
      const AQRCodeScale: Integer = 0): Boolean;
    function GetReceiptText(const AReceiptId: string; out ATextContent: string): Boolean;
    function GetReceiptQRCode(const AReceiptId: string; out AFileName: string): Boolean;



  end;

implementation


constructor TAuthInfo.Create;
begin
  inherited Create;
  Token := '';
  TokenType := 'bearer';
  RefreshToken := '';
  ExpiresAt := 0;
end;

destructor TAuthInfo.Destroy;
begin
  inherited Destroy;
end;

{ TShiftBalanceData }
destructor TShiftBalanceData.Destroy;
var
  I: Integer;
begin
  // Звільняємо податки
  for I := 0 to High(Taxes) do
    if Assigned(Taxes[I]) then
      FreeAndNil(Taxes[I]);
  SetLength(Taxes, 0);

  // Звільняємо платежі
  for I := 0 to High(Payments) do
    if Assigned(Payments[I]) then
      FreeAndNil(Payments[I]);
  SetLength(Payments, 0);

  // Звільняємо службові операції
  for I := 0 to High(ServiceOperations) do
    if Assigned(ServiceOperations[I]) then
      FreeAndNil(ServiceOperations[I]);
  SetLength(ServiceOperations, 0);

  inherited Destroy;
end;

{ TShiftStatus }
destructor TShiftStatus.Destroy;
var
  I: Integer;
begin
  if Assigned(Balance) then
    FreeAndNil(Balance);

  // Звільняємо підписи
  for I := 0 to High(Signatures) do
    if Assigned(Signatures[I]) then
      FreeAndNil(Signatures[I]);
  SetLength(Signatures, 0);

  // Звільняємо службові операції
  for I := 0 to High(ServiceOperations) do
    if Assigned(ServiceOperations[I]) then
      FreeAndNil(ServiceOperations[I]);
  SetLength(ServiceOperations, 0);

  inherited Destroy;
end;

{ TShift }
destructor TShift.Destroy;
var
  I: Integer;
begin
  if Assigned(InitialTransaction) then
    FreeAndNil(InitialTransaction);
  if Assigned(ClosingTransaction) then
    FreeAndNil(ClosingTransaction);
  if Assigned(Balance) then
    FreeAndNil(Balance);
  if Assigned(CashRegister) then
    FreeAndNil(CashRegister);
  if Assigned(Cashier) then
    FreeAndNil(Cashier);

  // Звільняємо податки
  for I := 0 to High(Taxes) do
    if Assigned(Taxes[I]) then
      FreeAndNil(Taxes[I]);
  SetLength(Taxes, 0);

  // Звільняємо підписи
  for I := 0 to High(Signatures) do
    if Assigned(Signatures[I]) then
      FreeAndNil(Signatures[I]);
  SetLength(Signatures, 0);

  // Звільняємо службові операції
  for I := 0 to High(ServiceOperations) do
    if Assigned(ServiceOperations[I]) then
      FreeAndNil(ServiceOperations[I]);
  SetLength(ServiceOperations, 0);

  inherited Destroy;
end;

{ TReceiptResponse }
destructor TReceiptResponse.Destroy;
var
  I: Integer;
begin
  if Assigned(Transaction) then
    FreeAndNil(Transaction);

  // Звільняємо товари
  for I := 0 to High(Goods) do
    if Assigned(Goods[I]) then
      FreeAndNil(Goods[I]);
  SetLength(Goods, 0);

  // Звільняємо оплати
  for I := 0 to High(Payments) do
    if Assigned(Payments[I]) then
      FreeAndNil(Payments[I]);
  SetLength(Payments, 0);

  // Звільняємо податки
  for I := 0 to High(Taxes) do
    if Assigned(Taxes[I]) then
      FreeAndNil(Taxes[I]);
  SetLength(Taxes, 0);

  // Звільняємо знижки
  for I := 0 to High(Discounts) do
    if Assigned(Discounts[I]) then
      FreeAndNil(Discounts[I]);
  SetLength(Discounts, 0);

  // Звільняємо сервісний обмін валюти
  SetLength(ServiceCurrencyExchange, 0);

  if Assigned(Shift) then
    FreeAndNil(Shift);
  if Assigned(Custom) then
    FreeAndNil(Custom);
  if Assigned(Cashier) then
    FreeAndNil(Cashier);
  if Assigned(CashRegister) then
    FreeAndNil(CashRegister);
  if Assigned(CustomFields) then
    FreeAndNil(CustomFields);

  // Звільняємо підписи
  for I := 0 to High(Signatures) do
    if Assigned(Signatures[I]) then
      FreeAndNil(Signatures[I]);
  SetLength(Signatures, 0);

  // Звільняємо службові операції
  for I := 0 to High(ServiceOperations) do
    if Assigned(ServiceOperations[I]) then
      FreeAndNil(ServiceOperations[I]);
  SetLength(ServiceOperations, 0);

  inherited Destroy;
end;


{ TReceipt }
constructor TReceipt.Create;
begin
  inherited Create;

  // Ініціалізація рядкових полів
  Id := '';
  CashierName := '';
  Departament := '';
  Header := '';
  Footer := '';
  Barcode := '';
  OrderId := '';
  RelatedReceiptId := '';
  PreviousReceiptId := '';
  Context := '';
  StockCode := '';
  CurrencyExchange := '';

  // Ініціалізація типів за замовчуванням
  ReceiptType := rtSell; // або інший тип за замовчуванням
  Rounding := True;
  TechnicalReturn := False;
  IsPawnshop := False;
  IsOffline := False;
  OfflineSequenceNumber := 0;

  // Ініціалізація числових полів
  Sum := 0;
  TotalSum := 0;
  TotalPayment := 0;
  TotalRest := 0;
  Rest := 0;

  // Ініціалізація динамічних масивів
  SetLength(Goods, 0);
  SetLength(Discounts, 0);
  SetLength(Bonuses, 0);
  SetLength(Payments, 0);
  SetLength(Taxes, 0);
  SetLength(ServiceCurrencyExchange, 0);
  SetLength(Signatures, 0);
  SetLength(ServiceOperations, 0);

  // Ініціалізація об'єктів
  Delivery := nil;
  Custom := nil;
end;

destructor TReceipt.Destroy;
var
  i: Integer;
begin
  // Звільнення товарів
  for i := 0 to High(Goods) do
    if Assigned(Goods[i]) then
      Goods[i].Free;
  SetLength(Goods, 0);

  // Звільнення знижок
  for i := 0 to High(Discounts) do
    if Assigned(Discounts[i]) then
      Discounts[i].Free;
  SetLength(Discounts, 0);

  // Звільнення бонусів
  for i := 0 to High(Bonuses) do
    if Assigned(Bonuses[i]) then
      Bonuses[i].Free;
  SetLength(Bonuses, 0);

  // Звільнення оплат
  for i := 0 to High(Payments) do
    if Assigned(Payments[i]) then
      Payments[i].Free;
  SetLength(Payments, 0);

  // Звільнення податків
  for i := 0 to High(Taxes) do
    if Assigned(Taxes[i]) then
      Taxes[i].Free;
  SetLength(Taxes, 0);

  // Звільнення підписів
  for i := 0 to High(Signatures) do
    if Assigned(Signatures[i]) then
      Signatures[i].Free;
  SetLength(Signatures, 0);

  // Звільнення службових операцій
  for i := 0 to High(ServiceOperations) do
    if Assigned(ServiceOperations[i]) then
      ServiceOperations[i].Free;
  SetLength(ServiceOperations, 0);

  // Звільнення об'єктів
  if Assigned(Delivery) then
    FreeAndNil(Delivery);
  if Assigned(Custom) then
    FreeAndNil(Custom);

  inherited Destroy;
end;


{ TAPIError }
destructor TAPIError.Destroy;
begin
  inherited Destroy;
end;

{ TServiceOperation }
destructor TServiceOperation.Destroy;
begin
  Id := '';
  OperationType := '';
  Description := '';
  TransactionId := '';
  CashierId := '';
  ShiftId := '';
  FiscalNumber := '';
  DocumentNumber := '';
  OfflineId := '';

  inherited Destroy;
end;

{ TSignature }
destructor TSignature.Destroy;
begin
  // Вивільняємо всі рядкові поля
  SignatureType := '';
  Value := '';
  SignatoryName := '';
  SignatoryTin := '';
  Certificate := '';
  CertificateThumbprint := '';
  SignatureFormat := '';
  ValidationDetails := '';
  RelatedDocumentId := '';
  RelatedDocumentType := '';

  inherited Destroy;
end;

{ TCashOperation }
destructor TCashOperation.Destroy;
begin
  inherited Destroy;
end;

{ TShiftPayment }
destructor TShiftPayment.Destroy;
begin
  PaymentType := '';
  ProviderType := '';
  LabelText := '';
  inherited Destroy;
end;

{ TShiftTax }
destructor TShiftTax.Destroy;
begin
  Id := '';
  LabelText := '';
  Symbol := '';
  AdvancedCode := '';
  inherited Destroy;
end;

{ TBalanceInfo }
destructor TBalanceInfo.Destroy;
begin
  // Поки що нічого звільняти не потрібно, оскільки клас не містить складних об'єктів
  inherited Destroy;
end;

{ TShiftReport }
destructor TShiftReport.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(Payments) do
    if Assigned(Payments[I]) then
      FreeAndNil(Payments[I]);
  SetLength(Payments, 0);

  for I := 0 to High(Taxes) do
    if Assigned(Taxes[I]) then
      FreeAndNil(Taxes[I]);
  SetLength(Taxes, 0);

  inherited Destroy;
end;

{ TCashRegisterStatus }
destructor TCashRegisterStatus.Destroy;
begin
  inherited Destroy;
end;

{ TTax }
destructor TTax.Destroy;
begin
  inherited Destroy;
end;

{ TGood }
destructor TGood.Destroy;
begin
  SetLength(TaxCodes, 0);
  SetLength(ExciseBarcodes, 0);
  inherited Destroy;
end;

{ TGoodDiscount }
destructor TGoodDiscount.Destroy;
begin
  SetLength(TaxCodes, 0);
  inherited Destroy;
end;

{ TGoodItem }
destructor TGoodItem.Destroy;
var
  I: Integer;
begin
  // Звільняємо об'єкт товару, якщо він існує
  if Assigned(Good) then
    FreeAndNil(Good);

  // Звільняємо знижки
  for I := 0 to High(Discounts) do
    if Assigned(Discounts[I]) then
      FreeAndNil(Discounts[I]);
  SetLength(Discounts, 0);
  SetLength(Taxes, 0);
  inherited Destroy;
end;

{ TDelivery }
destructor TDelivery.Destroy;
begin
  SetLength(Emails, 0);
  inherited Destroy;
end;

{ TReceiptDiscount }
destructor TReceiptDiscount.Destroy;
begin
  SetLength(TaxCodes, 0);
  inherited Destroy;
end;

{ TBonus }
destructor TBonus.Destroy;
begin
  inherited Destroy;
end;

destructor TPayment.Destroy;
begin
  // Вивільняємо всі рядкові поля
  LabelText := '';
  PLabel := '';
  ProviderType := '';
  CardMask := '';
  BankName := '';
  AuthCode := '';
  RRN := '';
  PaymentSystem := '';
  OwnerName := '';
  Terminal := '';
  AcquirerAndSeller := '';
  Acquiring := '';
  ReceiptNo := '';
  TapxphoneTerminal := '';
  Currency := '';
  ForeignCurrency := '';
  OfflineId := '';
  AdditionalInfo := '';
  ResponseCode := '';
  Status := '';
  CardType := '';
  IssuerCountry := '';
  CardBrand := '';
  LoyaltyProgram := '';

  inherited Destroy;
end;

{ TCustomSettings }
destructor TCustomSettings.Destroy;
begin
  // Вивільняємо всі рядкові поля
  HtmlGlobalHeader := '';
  HtmlGlobalFooter := '';
  HtmlBodyStyle := '';
  HtmlReceiptStyle := '';
  HtmlRulerStyle := '';
  HtmlLightBlockStyle := '';
  TextGlobalHeader := '';
  TextGlobalFooter := '';

  inherited Destroy;
end;

{ TTransaction }
destructor TTransaction.Destroy;
var I:integer;
begin
  // В деструкторе каждого класса добавить:
  for I := 0 to High(Signatures) do
  if Assigned(Signatures[I]) then
    FreeAndNil(Signatures[I]);
  SetLength(Signatures, 0);

  inherited Destroy;
end;

{ TCashier }
destructor TCashier.Destroy;
var I:integer;
begin
  // В деструкторе каждого класса добавить:
  for I := 0 to High(Signatures) do
  if Assigned(Signatures[I]) then
    FreeAndNil(Signatures[I]);
  SetLength(Signatures, 0);

  inherited Destroy;
end;


{ TCashRegister }
destructor TCashRegister.Destroy;
begin
  inherited Destroy;
end;

{  TReceiptCustomFields }
destructor TReceiptCustomFields.Destroy;
begin
  // Вивільняємо всі рядкові поля
  ReceiptNumber := '';
  CustomerName := '';
  CustomerAddress := '';
  ContractNumber := '';
  DocumentNumber := '';
  AdditionalInfo := '';
  PaymentDetails := '';
  CashierTitle := '';
  PreparedBy := '';
  CashWithdrawalPurpose := '';
  CashWithdrawalRecipient := '';
  CashWithdrawalPayer := '';
  CashWithdrawalSource := '';
  CashWithdrawalOrderNumber := '';
  CashWithdrawalBudgetCode := '';
  CashWithdrawalBudgetPeriod := '';
  CashWithdrawalDocumentType := '';
  CashWithdrawalTaxId := '';
  CashWithdrawalTaxIdSeries := '';
  CashWithdrawalTaxIdNumber := '';
  CashWithdrawalTaxIdIssuedBy := '';
  CashWithdrawalRepresentative := '';
  CashWithdrawalRepresentativeTaxId := '';
  CashWithdrawalRepresentativeTaxIdSeries := '';
  CashWithdrawalRepresentativeTaxIdNumber := '';
  CashWithdrawalRepresentativeTaxIdIssuedBy := '';
  CashWithdrawalRepresentativeDocument := '';
  CashWithdrawalRepresentativeDocumentSeries := '';
  CashWithdrawalRepresentativeDocumentNumber := '';
  CashWithdrawalRepresentativeDocumentIssuedBy := '';

  inherited Destroy;
end;

{ TReceiptWebAPI }
constructor TReceiptWebAPI.Create(ABaseURL, AClientName, AClientVersion,
  ALicenseKey: string; ALogProcedure: TLogProcedure = nil);
begin
  inherited Create;

  // ✅ СПОЧАТКУ створюємо всі об'єкти
  FAuthInfo := TAuthInfo.Create; // Вже ініціалізує поля за замовчуванням

  // Потім ініціалізуємо прості поля
  FBaseURL := ABaseURL;
  FClientName := AClientName;
  FClientVersion := AClientVersion;
  FLicenseKey := ALicenseKey;
  FLogProcedure := ALogProcedure;

  FLastError := '';
  FReceiptsDirectory := GetUserDir + 'checkbox_receipts/'; // Значення за замовчуванням
  FTempDirectory := GetUserDir + 'temp_receipts/'; // Значення за замовчуванням

  FUsername := '';
  FPassword := '';
  FCurrentShiftId := '';
  FLastShiftReport := nil;
  FCurrentBalance := 0;
  FLastBalanceUpdate := 0;
  FBalanceUpdateInterval := 300;

  FLastCashRegisterUpdate := 0;
  FLastCashRegisterResponse := '';
  Randomize;

  // Логування для налагодження
  if Assigned(FLogProcedure) then
    FLogProcedure('TReceiptWebAPI створено успішно. FAuthInfo ініціалізовано.');
end;

destructor TReceiptWebAPI.Destroy;
begin
  inherited Destroy;
  if Assigned(FLastShiftReport) then  FreeAndNil(FLastShiftReport);
  if Assigned(FAuthInfo) then  FreeAndNil(FAuthInfo);
end;






function TReceiptResponse.ParseFromJSON(const JSONString: string; AWebAPI: TReceiptWebAPI): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;

  TransactionObj, GoodObj, PaymentObj, TaxObj, DiscountObj, ShiftObj,
  CashierObj, CashRegObj, ShiftBalanceObj, CustomObj: TJSONObject;

  GoodsArray, PaymentsArray, TaxesArray, DiscountsArray, ServiceArray,
  ShiftTaxesArray, GoodTaxesArray, GoodDiscountsArray,SignaturesArray : TJSONArray;

  I, J, K: Integer;
  TempStr: string;
  TempDate: TDateTime;
begin
  Result := False;
  JsonData := nil;
  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);
  try
   try
    JsonData := JsonParser.Parse as TJSONObject;

    // ⚠️ НОВЕ: Обробка помилок 400/422 з 'message'
          if JsonData.Find('message') <> nil then
          begin
            Status := rsError;
            ErrorMessage := JsonData.Get('message', '');
            AWebAPI.Log('Сервер повернув помилку валідації: ' + ErrorMessage);
            // Опціонально: Парсити 'details' якщо є
            if JsonData.Find('details') <> nil then
              ErrorMessage := ErrorMessage + ' | Details: ' + JsonData.Get('details', '');
            Exit; // Не парсити далі, бо це помилка
          end;

    // Парсимо основні поля
    Id := JsonData.Get('id', '');
    ReceiptType := JsonData.Get('receipt_type', '');
    RType := JsonData.Get('type', '');
    Serial := JsonData.Get('serial', 0);
    Status := AWebAPI.StringToReceiptStatus(JsonData.Get('status', ''));
    TotalSum := JsonData.Get('total_sum', 0);
    Sum := JsonData.Get('sum', 0);
    TotalPayment := JsonData.Get('total_payment', 0);
    TotalRest := JsonData.Get('total_rest', 0);
    Rest := JsonData.Get('rest', 0);
    RoundSum := JsonData.Get('round_sum', 0);
    FiscalCode := JsonData.Get('fiscal_code', '');
    FiscalDate := AWebAPI.ParseDateTime(JsonData.Get('fiscal_date', ''));
    DeliveredAt := AWebAPI.ParseDateTime(JsonData.Get('delivered_at', ''));
    CreatedAt := AWebAPI.ParseDateTime(JsonData.Get('created_at', ''));
    UpdatedAt := AWebAPI.ParseDateTime(JsonData.Get('updated_at', ''));
    OrderId := JsonData.Get('order_id', '');
    Header := JsonData.Get('header', '');
    Footer := JsonData.Get('footer', '');
    Barcode := JsonData.Get('barcode', '');
    Context := JsonData.Get('context', '');
    IsCreatedOffline := JsonData.Get('is_created_offline', False);
    IsSentDps := JsonData.Get('is_sent_dps', False);
    SentDpsAt := AWebAPI.ParseDateTime(JsonData.Get('sent_dps_at', ''));
    TaxUrl := JsonData.Get('tax_url', '');
    RelatedReceiptId := JsonData.Get('related_receipt_id', '');
    TechnicalReturn := JsonData.Get('technical_return', False);
    StockCode := JsonData.Get('stock_code', '');
    CurrencyExchange := JsonData.Get('currency_exchange', '');
    ControlNumber := JsonData.Get('control_number', '');
    OfflineSequenceNumber := JsonData.Get('offline_sequence_number', 0);
    IsOffline := JsonData.Get('is_offline', False);
    FiscalTimestamp := AWebAPI.ParseDateTime(JsonData.Get('fiscal_timestamp', ''));
    ProcessingStatus := JsonData.Get('processing_status', '');

    // Парсимо transaction з перевіркою на тип
    if (JsonData.Find('transaction') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('transaction')].JSONType = jtObject) then
    begin
      TransactionObj := JsonData.Objects['transaction'];
      if Assigned(TransactionObj) then
      begin
        Transaction := TTransaction.Create;
        Transaction.Id := TransactionObj.Get('id', '');
        Transaction.TransactionType := TransactionObj.Get('type', '');
        Transaction.Serial := TransactionObj.Get('serial', 0);
        Transaction.Status := AWebAPI.StringToTransactionStatus(TransactionObj.Get('status', ''));
        Transaction.RequestSignedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_signed_at', ''));
        Transaction.RequestReceivedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_received_at', ''));
        Transaction.ResponseStatus := TransactionObj.Get('response_status', '');
        Transaction.ResponseErrorMessage := TransactionObj.Get('response_error_message', '');
        Transaction.ResponseId := TransactionObj.Get('response_id', '');
        Transaction.OfflineId := TransactionObj.Get('offline_id', '');
        Transaction.CreatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('created_at', ''));
        Transaction.UpdatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('updated_at', ''));
        Transaction.OriginalDatetime := AWebAPI.ParseDateTime(TransactionObj.Get('original_datetime', ''));
        Transaction.PreviousHash := TransactionObj.Get('previous_hash', '');
      end;
    end
    else
    begin
      Transaction := nil;
    end;

    // Парсимо goods з перевіркою на тип
    if (JsonData.Find('goods') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('goods')].JSONType = jtArray) then
    begin
      GoodsArray := JsonData.Arrays['goods'];
      if Assigned(GoodsArray) then
      begin
        SetLength(Goods, GoodsArray.Count);
        for I := 0 to GoodsArray.Count - 1 do
        begin
          if GoodsArray.Items[I].JSONType = jtObject then
          begin
            GoodObj := GoodsArray.Objects[I];
            if Assigned(GoodObj) then
            begin
              Goods[I] := TGoodItem.Create;
              Goods[I].GoodId := GoodObj.Get('good_id', '');
              Goods[I].Quantity := GoodObj.Get('quantity', 0);
              Goods[I].Sum := GoodObj.Get('sum', 0);
              Goods[I].IsReturn := GoodObj.Get('is_return', False);
              Goods[I].IsWinningsPayout := GoodObj.Get('is_winnings_payout', False);
              Goods[I].TotalSum := GoodObj.Get('total_sum', 0);

              // Парсинг товару
              if (GoodObj.Find('good') <> nil) and
                 (GoodObj.Items[GoodObj.IndexOfName('good')].JSONType = jtObject) then
              begin
                Goods[I].Good := TGood.Create;
                Goods[I].Good.Code := GoodObj.Objects['good'].Get('code', '');
                Goods[I].Good.Name := GoodObj.Objects['good'].Get('name', '');
                Goods[I].Good.Price := GoodObj.Objects['good'].Get('price', 0);
                Goods[I].Good.Barcode := GoodObj.Objects['good'].Get('barcode', '');
                Goods[I].Good.Header := GoodObj.Objects['good'].Get('header', '');
                Goods[I].Good.Footer := GoodObj.Objects['good'].Get('footer', '');
                Goods[I].Good.Uktzed := GoodObj.Objects['good'].Get('uktzed', '');

                // Парсинг масиву tax_codes для товару
                if (GoodObj.Objects['good'].Find('tax_codes') <> nil) and
                   (GoodObj.Objects['good'].Items[GoodObj.Objects['good'].IndexOfName('tax_codes')].JSONType = jtArray) then
                begin
                  GoodTaxesArray := GoodObj.Objects['good'].Arrays['tax_codes'];
                  if Assigned(GoodTaxesArray) then
                  begin
                    SetLength(Goods[I].Good.TaxCodes, GoodTaxesArray.Count);
                    for J := 0 to GoodTaxesArray.Count - 1 do
                      Goods[I].Good.TaxCodes[J] := GoodTaxesArray.Items[J].AsInteger;
                  end;
                end;

                // Парсинг масиву excise_barcodes для товару
                if (GoodObj.Objects['good'].Find('excise_barcodes') <> nil) and
                   (GoodObj.Objects['good'].Items[GoodObj.Objects['good'].IndexOfName('excise_barcodes')].JSONType = jtArray) then
                begin
                  ServiceArray := GoodObj.Objects['good'].Arrays['excise_barcodes'];
                  if Assigned(ServiceArray) then
                  begin
                    SetLength(Goods[I].Good.ExciseBarcodes, ServiceArray.Count);
                    for J := 0 to ServiceArray.Count - 1 do
                      Goods[I].Good.ExciseBarcodes[J] := ServiceArray.Items[J].AsString;
                  end;
                end;
              end;

              // Парсинг податків для позиції товару
              if (GoodObj.Find('taxes') <> nil) and
                 (GoodObj.Items[GoodObj.IndexOfName('taxes')].JSONType = jtArray) then
              begin
                GoodTaxesArray := GoodObj.Arrays['taxes'];
                if Assigned(GoodTaxesArray) then
                begin
                  SetLength(Goods[I].Taxes, GoodTaxesArray.Count);
                  for J := 0 to GoodTaxesArray.Count - 1 do
                  begin
                    if GoodTaxesArray.Items[J].JSONType = jtObject then
                    begin
                      TaxObj := GoodTaxesArray.Objects[J];
                      if Assigned(TaxObj) then
                      begin
                        Goods[I].Taxes[J] := TTax.Create;
                        Goods[I].Taxes[J].Id := TaxObj.Get('id', '');
                        Goods[I].Taxes[J].Code := TaxObj.Get('code', 0);
                        Goods[I].Taxes[J].LabelText := TaxObj.Get('label', '');
                        Goods[I].Taxes[J].Symbol := TaxObj.Get('symbol', '');
                        Goods[I].Taxes[J].Rate := TaxObj.Get('rate', 0.0);
                        Goods[I].Taxes[J].ExtraRate := TaxObj.Get('extra_rate', 0.0);
                        Goods[I].Taxes[J].Included := TaxObj.Get('included', False);
                        Goods[I].Taxes[J].NoVat := TaxObj.Get('no_vat', False);
                        Goods[I].Taxes[J].AdvancedCode := TaxObj.Get('advanced_code', '');
                        Goods[I].Taxes[J].Value := TaxObj.Get('value', 0.0);
                        Goods[I].Taxes[J].ExtraValue := TaxObj.Get('extra_value', 0.0);
                      end;
                    end;
                  end;
                end;
              end;

              // Парсинг знижок для позиції товару
              if (GoodObj.Find('discounts') <> nil) and
                 (GoodObj.Items[GoodObj.IndexOfName('discounts')].JSONType = jtArray) then
              begin
                GoodDiscountsArray := GoodObj.Arrays['discounts'];
                if Assigned(GoodDiscountsArray) then
                begin
                  SetLength(Goods[I].Discounts, GoodDiscountsArray.Count);
                  for J := 0 to GoodDiscountsArray.Count - 1 do
                  begin
                    if GoodDiscountsArray.Items[J].JSONType = jtObject then
                    begin
                      DiscountObj := GoodDiscountsArray.Objects[J];
                      if Assigned(DiscountObj) then
                      begin
                        Goods[I].Discounts[J] := TGoodDiscount.Create;
                        TempStr := DiscountObj.Get('type', '');
                        if TempStr = 'DISCOUNT' then
                          Goods[I].Discounts[J].DiscountType := dtDiscount
                        else if TempStr = 'EXTRA_CHARGE' then
                          Goods[I].Discounts[J].DiscountType := dtExtraCharge;

                        TempStr := DiscountObj.Get('mode', '');
                        if TempStr = 'VALUE' then
                          Goods[I].Discounts[J].Mode := dmValue
                        else if TempStr = 'PERCENT' then
                          Goods[I].Discounts[J].Mode := dmPercent;

                        Goods[I].Discounts[J].Value := DiscountObj.Get('value', 0.0);
                        Goods[I].Discounts[J].TaxCode := DiscountObj.Get('tax_code', 0);
                        Goods[I].Discounts[J].Name := DiscountObj.Get('name', '');
                        Goods[I].Discounts[J].Privilege := DiscountObj.Get('privilege', '');

                        // Парсинг масиву tax_codes
                        if (DiscountObj.Find('tax_codes') <> nil) and
                           (DiscountObj.Items[DiscountObj.IndexOfName('tax_codes')].JSONType = jtArray) then
                        begin
                          TaxesArray := DiscountObj.Arrays['tax_codes'];
                          if Assigned(TaxesArray) then
                          begin
                            SetLength(Goods[I].Discounts[J].TaxCodes, TaxesArray.Count);
                            for K := 0 to TaxesArray.Count - 1 do
                              Goods[I].Discounts[J].TaxCodes[K] := TaxesArray.Items[K].AsInteger;
                          end;
                        end;
                      end;
                    end;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    // Парсимо payments з перевіркою на тип
    if (JsonData.Find('payments') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('payments')].JSONType = jtArray) then
    begin
      PaymentsArray := JsonData.Arrays['payments'];
      if Assigned(PaymentsArray) then
      begin
        SetLength(Payments, PaymentsArray.Count);
        for I := 0 to PaymentsArray.Count - 1 do
        begin
          if PaymentsArray.Items[I].JSONType = jtObject then
          begin
            PaymentObj := PaymentsArray.Objects[I];
            if Assigned(PaymentObj) then
            begin
              Payments[I] := TPayment.Create;
              TempStr := PaymentObj.Get('type', '');
              if TempStr = 'CASHLESS' then
                Payments[I].PaymentType := ptCashless
              else if TempStr = 'CASH' then
                Payments[I].PaymentType := ptCash
              else
                Payments[I].PaymentType := ptCashless; // За замовчуванням

              Payments[I].LabelText := PaymentObj.Get('label', '');
              Payments[I].PLabel := PaymentObj.Get('label', '');
              Payments[I].Value := PaymentObj.Get('value', 0);
              Payments[I].Code := PaymentObj.Get('code', 0);
              Payments[I].PawnshopIsReturn := PaymentObj.Get('pawnshop_is_return', False);
              Payments[I].ProviderType := PaymentObj.Get('provider_type', '');
              Payments[I].Commission := PaymentObj.Get('commission', 0.0);
              Payments[I].CardMask := PaymentObj.Get('card_mask', '');
              Payments[I].BankName := PaymentObj.Get('bank_name', '');
              Payments[I].AuthCode := PaymentObj.Get('auth_code', '');
              Payments[I].RRN := PaymentObj.Get('rrn', '');
              Payments[I].PaymentSystem := PaymentObj.Get('payment_system', '');
              Payments[I].OwnerName := PaymentObj.Get('owner_name', '');
              Payments[I].Terminal := PaymentObj.Get('terminal', '');
              Payments[I].AcquirerAndSeller := PaymentObj.Get('acquirer_and_seller', '');
              Payments[I].Acquiring := PaymentObj.Get('acquiring', '');
              Payments[I].ReceiptNo := PaymentObj.Get('receipt_no', '');
              Payments[I].SignatureRequired := PaymentObj.Get('signature_required', False);
              Payments[I].TapxphoneTerminal := PaymentObj.Get('tapxphone_terminal', '');
            end;
          end;
        end;
      end;
    end;

    // Парсимо taxes з перевіркою на тип
    if (JsonData.Find('taxes') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('taxes')].JSONType = jtArray) then
    begin
      TaxesArray := JsonData.Arrays['taxes'];
      if Assigned(TaxesArray) then
      begin
        SetLength(Taxes, TaxesArray.Count);
        for I := 0 to TaxesArray.Count - 1 do
        begin
          if TaxesArray.Items[I].JSONType = jtObject then
          begin
            TaxObj := TaxesArray.Objects[I];
            if Assigned(TaxObj) then
            begin
              Taxes[I] := TTax.Create;
              Taxes[I].Id := TaxObj.Get('id', '');
              Taxes[I].Code := TaxObj.Get('code', 0);
              Taxes[I].LabelText := TaxObj.Get('label', '');
              Taxes[I].Symbol := TaxObj.Get('symbol', '');
              Taxes[I].Rate := TaxObj.Get('rate', 0.0);
              Taxes[I].ExtraRate := TaxObj.Get('extra_rate', 0.0);
              Taxes[I].Included := TaxObj.Get('included', False);
              Taxes[I].NoVat := TaxObj.Get('no_vat', False);
              Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');
              Taxes[I].Value := TaxObj.Get('value', 0.0);
              Taxes[I].ExtraValue := TaxObj.Get('extra_value', 0.0);
            end;
          end;
        end;
      end;
    end;

    // Парсимо discounts з перевіркою на тип
    if (JsonData.Find('discounts') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('discounts')].JSONType = jtArray) then
    begin
      DiscountsArray := JsonData.Arrays['discounts'];
      if Assigned(DiscountsArray) then
      begin
        SetLength(Discounts, DiscountsArray.Count);
        for I := 0 to DiscountsArray.Count - 1 do
        begin
          if DiscountsArray.Items[I].JSONType = jtObject then
          begin
            DiscountObj := DiscountsArray.Objects[I];
            if Assigned(DiscountObj) then
            begin
              Discounts[I] := TReceiptDiscount.Create;
              TempStr := DiscountObj.Get('type', '');
              if TempStr = 'DISCOUNT' then
                Discounts[I].DiscountType := dtDiscount
              else if TempStr = 'EXTRA_CHARGE' then
                Discounts[I].DiscountType := dtExtraCharge;

              TempStr := DiscountObj.Get('mode', '');
              if TempStr = 'VALUE' then
                Discounts[I].Mode := dmValue
              else if TempStr = 'PERCENT' then
                Discounts[I].Mode := dmPercent;

              Discounts[I].Value := DiscountObj.Get('value', 0.0);
              Discounts[I].TaxCode := DiscountObj.Get('tax_code', 0);
              Discounts[I].Name := DiscountObj.Get('name', '');
              Discounts[I].Privilege := DiscountObj.Get('privilege', '');
              Discounts[I].Sum := DiscountObj.Get('sum', 0);

              // Парсинг масиву tax_codes для знижок чеку
              if (DiscountObj.Find('tax_codes') <> nil) and
                 (DiscountObj.Items[DiscountObj.IndexOfName('tax_codes')].JSONType = jtArray) then
              begin
                TaxesArray := DiscountObj.Arrays['tax_codes'];
                if Assigned(TaxesArray) then
                begin
                  SetLength(Discounts[I].TaxCodes, TaxesArray.Count);
                  for J := 0 to TaxesArray.Count - 1 do
                    Discounts[I].TaxCodes[J] := TaxesArray.Items[J].AsInteger;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    // Парсимо service_currency_exchange з перевіркою на тип
    if (JsonData.Find('service_currency_exchange') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('service_currency_exchange')].JSONType = jtArray) then
    begin
      ServiceArray := JsonData.Arrays['service_currency_exchange'];
      if Assigned(ServiceArray) then
      begin
        SetLength(ServiceCurrencyExchange, ServiceArray.Count);
        for I := 0 to ServiceArray.Count - 1 do
          ServiceCurrencyExchange[I] := ServiceArray.Items[I].AsString;
      end;
    end;

    // Парсимо shift з перевіркою на тип
    if (JsonData.Find('shift') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('shift')].JSONType = jtObject) then
    begin
      ShiftObj := JsonData.Objects['shift'];
      if Assigned(ShiftObj) then
      begin
        Shift := TShift.Create;
        Shift.Id := ShiftObj.Get('id', '');
        Shift.Serial := ShiftObj.Get('serial', 0);
        Shift.Status := ShiftObj.Get('status', '');
        Shift.ZReport := ShiftObj.Get('z_report', '');
        Shift.OpenedAt := AWebAPI.ParseDateTime(ShiftObj.Get('opened_at', ''));
        Shift.ClosedAt := AWebAPI.ParseDateTime(ShiftObj.Get('closed_at', ''));
        Shift.CreatedAt := AWebAPI.ParseDateTime(ShiftObj.Get('created_at', ''));
        Shift.UpdatedAt := AWebAPI.ParseDateTime(ShiftObj.Get('updated_at', ''));
        Shift.EmergencyClose := ShiftObj.Get('emergency_close', False);
        Shift.EmergencyCloseDetails := ShiftObj.Get('emergency_close_details', '');

        // Парсимо InitialTransaction
        if (ShiftObj.Find('initial_transaction') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('initial_transaction')].JSONType = jtObject) then
        begin
          TransactionObj := ShiftObj.Objects['initial_transaction'];
          if Assigned(TransactionObj) then
          begin
            Shift.InitialTransaction := TTransaction.Create;
            Shift.InitialTransaction.Id := TransactionObj.Get('id', '');
            Shift.InitialTransaction.TransactionType := TransactionObj.Get('type', '');
            Shift.InitialTransaction.Serial := TransactionObj.Get('serial', 0);
            Shift.InitialTransaction.Status := AWebAPI.StringToTransactionStatus(TransactionObj.Get('status', ''));
            Shift.InitialTransaction.RequestSignedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_signed_at', ''));
            Shift.InitialTransaction.RequestReceivedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_received_at', ''));
            Shift.InitialTransaction.ResponseStatus := TransactionObj.Get('response_status', '');
            Shift.InitialTransaction.ResponseErrorMessage := TransactionObj.Get('response_error_message', '');
            Shift.InitialTransaction.ResponseId := TransactionObj.Get('response_id', '');
            Shift.InitialTransaction.OfflineId := TransactionObj.Get('offline_id', '');
            Shift.InitialTransaction.CreatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('created_at', ''));
            Shift.InitialTransaction.UpdatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('updated_at', ''));
            Shift.InitialTransaction.OriginalDatetime := AWebAPI.ParseDateTime(TransactionObj.Get('original_datetime', ''));
            Shift.InitialTransaction.PreviousHash := TransactionObj.Get('previous_hash', '');
          end;
        end;

        // Парсимо ClosingTransaction
        if (ShiftObj.Find('closing_transaction') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('closing_transaction')].JSONType = jtObject) then
        begin
          TransactionObj := ShiftObj.Objects['closing_transaction'];
          if Assigned(TransactionObj) then
          begin
            Shift.ClosingTransaction := TTransaction.Create;
            Shift.ClosingTransaction.Id := TransactionObj.Get('id', '');
            Shift.ClosingTransaction.TransactionType := TransactionObj.Get('type', '');
            Shift.ClosingTransaction.Serial := TransactionObj.Get('serial', 0);
            Shift.ClosingTransaction.Status := AWebAPI.StringToTransactionStatus(TransactionObj.Get('status', ''));
            Shift.ClosingTransaction.RequestSignedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_signed_at', ''));
            Shift.ClosingTransaction.RequestReceivedAt := AWebAPI.ParseDateTime(TransactionObj.Get('request_received_at', ''));
            Shift.ClosingTransaction.ResponseStatus := TransactionObj.Get('response_status', '');
            Shift.ClosingTransaction.ResponseErrorMessage := TransactionObj.Get('response_error_message', '');
            Shift.ClosingTransaction.ResponseId := TransactionObj.Get('response_id', '');
            Shift.ClosingTransaction.OfflineId := TransactionObj.Get('offline_id', '');
            Shift.ClosingTransaction.CreatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('created_at', ''));
            Shift.ClosingTransaction.UpdatedAt := AWebAPI.ParseDateTime(TransactionObj.Get('updated_at', ''));
            Shift.ClosingTransaction.OriginalDatetime := AWebAPI.ParseDateTime(TransactionObj.Get('original_datetime', ''));
            Shift.ClosingTransaction.PreviousHash := TransactionObj.Get('previous_hash', '');
          end;
        end;

        // Парсимо Cashier з перевіркою на тип
        if (ShiftObj.Find('cashier') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('cashier')].JSONType = jtObject) then
        begin
          CashierObj := ShiftObj.Objects['cashier'];
          if Assigned(CashierObj) then
          begin
            Shift.Cashier := TCashier.Create;
            Shift.Cashier.Id := CashierObj.Get('id', '');
            Shift.Cashier.FullName := CashierObj.Get('full_name', '');
            Shift.Cashier.Nin := CashierObj.Get('nin', '');
            Shift.Cashier.KeyId := CashierObj.Get('key_id', '');
            Shift.Cashier.SignatureType := CashierObj.Get('signature_type', '');
            Shift.Cashier.CertificateEnd := AWebAPI.ParseDateTime(CashierObj.Get('certificate_end', ''));
            Shift.Cashier.Blocked := CashierObj.Get('blocked', False);
            Shift.Cashier.CreatedAt := AWebAPI.ParseDateTime(CashierObj.Get('created_at', ''));
            Shift.Cashier.UpdatedAt := AWebAPI.ParseDateTime(CashierObj.Get('updated_at', ''));
          end;
        end;

        // Парсимо CashRegister з перевіркою на тип
        if (ShiftObj.Find('cash_register') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('cash_register')].JSONType = jtObject) then
        begin
          CashRegObj := ShiftObj.Objects['cash_register'];
          if Assigned(CashRegObj) then
          begin
            Shift.CashRegister := TCashRegister.Create;
            Shift.CashRegister.Id := CashRegObj.Get('id', '');
            Shift.CashRegister.FiscalNumber := CashRegObj.Get('fiscal_number', '');
            Shift.CashRegister.Active := CashRegObj.Get('active', False);
            Shift.CashRegister.Number := CashRegObj.Get('number', '');
            Shift.CashRegister.CreatedAt := AWebAPI.ParseDateTime(CashRegObj.Get('created_at', ''));
            Shift.CashRegister.UpdatedAt := AWebAPI.ParseDateTime(CashRegObj.Get('updated_at', ''));
          end;
        end;

        // Парсимо ShiftBalance з перевіркою на тип
        if (ShiftObj.Find('balance') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('balance')].JSONType = jtObject) then
        begin
          ShiftBalanceObj := ShiftObj.Objects['balance'];
          if Assigned(ShiftBalanceObj) then
          begin
            Shift.Balance := TShiftBalanceData.Create;
            Shift.Balance.Initial := ShiftBalanceObj.Get('initial', 0);
            Shift.Balance.Balance := ShiftBalanceObj.Get('balance', 0);
            Shift.Balance.CashSales := ShiftBalanceObj.Get('cash_sales', 0);
            Shift.Balance.CardSales := ShiftBalanceObj.Get('card_sales', 0);
            Shift.Balance.DiscountsSum := ShiftBalanceObj.Get('discounts_sum', 0);
            Shift.Balance.ExtraChargeSum := ShiftBalanceObj.Get('extra_charge_sum', 0);
            Shift.Balance.CashReturns := ShiftBalanceObj.Get('cash_returns', 0);
            Shift.Balance.CardReturns := ShiftBalanceObj.Get('card_returns', 0);
            Shift.Balance.ServiceIn := ShiftBalanceObj.Get('service_in', 0);
            Shift.Balance.ServiceOut := ShiftBalanceObj.Get('service_out', 0);
            Shift.Balance.SalesRoundUp := ShiftBalanceObj.Get('sales_round_up', 0);
            Shift.Balance.SalesRoundDown := ShiftBalanceObj.Get('sales_round_down', 0);
            Shift.Balance.ReturnsRoundUp := ShiftBalanceObj.Get('returns_round_up', 0);
            Shift.Balance.ReturnsRoundDown := ShiftBalanceObj.Get('returns_round_down', 0);
            Shift.Balance.UpdatedAt := AWebAPI.ParseDateTime(ShiftBalanceObj.Get('updated_at', ''));
            Shift.Balance.SellReceiptsCount := ShiftBalanceObj.Get('sell_receipts_count', 0);
            Shift.Balance.ReturnReceiptsCount := ShiftBalanceObj.Get('return_receipts_count', 0);
            Shift.Balance.CashWithdrawalReceiptsCount := ShiftBalanceObj.Get('cash_withdrawal_receipts_count', 0);
            Shift.Balance.LastReceiptId := ShiftBalanceObj.Get('last_receipt_id', '');

            // Парсимо податки балансу
            if (ShiftBalanceObj.Find('taxes') <> nil) and
               (ShiftBalanceObj.Items[ShiftBalanceObj.IndexOfName('taxes')].JSONType = jtArray) then
            begin
              ShiftTaxesArray := ShiftBalanceObj.Arrays['taxes'];
              if Assigned(ShiftTaxesArray) then
              begin
                SetLength(Shift.Balance.Taxes, ShiftTaxesArray.Count);
                for I := 0 to ShiftTaxesArray.Count - 1 do
                begin
                  if ShiftTaxesArray.Items[I].JSONType = jtObject then
                  begin
                    TaxObj := ShiftTaxesArray.Objects[I];
                    if Assigned(TaxObj) then
                    begin
                      Shift.Balance.Taxes[I] := TShiftTax.Create;
                      Shift.Balance.Taxes[I].Id := TaxObj.Get('id', '');
                      Shift.Balance.Taxes[I].Code := TaxObj.Get('code', 0);
                      Shift.Balance.Taxes[I].LabelText := TaxObj.Get('label', '');
                      Shift.Balance.Taxes[I].Symbol := TaxObj.Get('symbol', '');
                      Shift.Balance.Taxes[I].Rate := TaxObj.Get('rate', 0.0);
                      Shift.Balance.Taxes[I].ExtraRate := TaxObj.Get('extra_rate', 0.0);
                      Shift.Balance.Taxes[I].SellSum := TaxObj.Get('sell_sum', 0);
                      Shift.Balance.Taxes[I].ReturnSum := TaxObj.Get('return_sum', 0);
                      Shift.Balance.Taxes[I].SalesTurnover := TaxObj.Get('sales_turnover', 0);
                      Shift.Balance.Taxes[I].ReturnsTurnover := TaxObj.Get('returns_turnover', 0);
                      Shift.Balance.Taxes[I].SetupDate := AWebAPI.ParseDateTime(TaxObj.Get('setup_date', ''));
                      Shift.Balance.Taxes[I].Included := TaxObj.Get('included', False);
                      Shift.Balance.Taxes[I].NoVat := TaxObj.Get('no_vat', False);
                      Shift.Balance.Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');
                      Shift.Balance.Taxes[I].Sales := TaxObj.Get('sales', 0.0);
                      Shift.Balance.Taxes[I].Returns := TaxObj.Get('returns', 0.0);
                      Shift.Balance.Taxes[I].TaxSum := TaxObj.Get('tax_sum', 0.0);
                      Shift.Balance.Taxes[I].ExtraTaxSum := TaxObj.Get('extra_tax_sum', 0.0);
                    end;
                  end;
                end;
              end;
            end;

            // Парсимо платежі балансу
            if (ShiftBalanceObj.Find('payments') <> nil) and
               (ShiftBalanceObj.Items[ShiftBalanceObj.IndexOfName('payments')].JSONType = jtArray) then
            begin
              PaymentsArray := ShiftBalanceObj.Arrays['payments'];
              if Assigned(PaymentsArray) then
              begin
                SetLength(Shift.Balance.Payments, PaymentsArray.Count);
                for I := 0 to PaymentsArray.Count - 1 do
                begin
                  if PaymentsArray.Items[I].JSONType = jtObject then
                  begin
                    PaymentObj := PaymentsArray.Objects[I];
                    if Assigned(PaymentObj) then
                    begin
                      Shift.Balance.Payments[I] := TShiftPayment.Create;
                      Shift.Balance.Payments[I].PaymentType := PaymentObj.Get('type', '');
                      Shift.Balance.Payments[I].ProviderType := PaymentObj.Get('provider_type', '');
                      Shift.Balance.Payments[I].Code := PaymentObj.Get('code', 0);
                      Shift.Balance.Payments[I].LabelText := PaymentObj.Get('label', '');
                      Shift.Balance.Payments[I].SellSum := PaymentObj.Get('sell_sum', 0);
                      Shift.Balance.Payments[I].ReturnSum := PaymentObj.Get('return_sum', 0);
                      Shift.Balance.Payments[I].ServiceIn := PaymentObj.Get('service_in', 0);
                      Shift.Balance.Payments[I].ServiceOut := PaymentObj.Get('service_out', 0);
                      Shift.Balance.Payments[I].CashWithdrawal := PaymentObj.Get('cash_withdrawal', 0);
                      Shift.Balance.Payments[I].CashWithdrawalCommission := PaymentObj.Get('cash_withdrawal_commission', 0);
                    end;
                  end;
                end;
              end;
            end;
          end;
        end;

        // Парсимо ShiftTaxes з перевіркою на тип
        if (ShiftObj.Find('taxes') <> nil) and
           (ShiftObj.Items[ShiftObj.IndexOfName('taxes')].JSONType = jtArray) then
        begin
          ShiftTaxesArray := ShiftObj.Arrays['taxes'];
          if Assigned(ShiftTaxesArray) then
          begin
            SetLength(Shift.Taxes, ShiftTaxesArray.Count);
            for I := 0 to ShiftTaxesArray.Count - 1 do
            begin
              if ShiftTaxesArray.Items[I].JSONType = jtObject then
              begin
                TaxObj := ShiftTaxesArray.Objects[I];
                if Assigned(TaxObj) then
                begin
                  Shift.Taxes[I] := TShiftTax.Create;
                  Shift.Taxes[I].Id := TaxObj.Get('id', '');
                  Shift.Taxes[I].Code := TaxObj.Get('code', 0);
                  Shift.Taxes[I].LabelText := TaxObj.Get('label', '');
                  Shift.Taxes[I].Symbol := TaxObj.Get('symbol', '');
                  Shift.Taxes[I].Rate := TaxObj.Get('rate', 0.0);
                  Shift.Taxes[I].ExtraRate := TaxObj.Get('extra_rate', 0.0);
                  Shift.Taxes[I].SellSum := TaxObj.Get('sell_sum', 0);
                  Shift.Taxes[I].ReturnSum := TaxObj.Get('return_sum', 0);
                  Shift.Taxes[I].SalesTurnover := TaxObj.Get('sales_turnover', 0);
                  Shift.Taxes[I].ReturnsTurnover := TaxObj.Get('returns_turnover', 0);
                  Shift.Taxes[I].SetupDate := AWebAPI.ParseDateTime(TaxObj.Get('setup_date', ''));
                  Shift.Taxes[I].Included := TaxObj.Get('included', False);
                  Shift.Taxes[I].NoVat := TaxObj.Get('no_vat', False);
                  Shift.Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');
                  Shift.Taxes[I].Sales := TaxObj.Get('sales', 0.0);
                  Shift.Taxes[I].Returns := TaxObj.Get('returns', 0.0);
                  Shift.Taxes[I].TaxSum := TaxObj.Get('tax_sum', 0.0);
                  Shift.Taxes[I].ExtraTaxSum := TaxObj.Get('extra_tax_sum', 0.0);
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    // Парсимо cashier з перевіркою на тип
    if (JsonData.Find('cashier') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('cashier')].JSONType = jtObject) then
    begin
      CashierObj := JsonData.Objects['cashier'];
      if Assigned(CashierObj) then
      begin
        Cashier := TCashier.Create;
        Cashier.Id := CashierObj.Get('id', '');
        Cashier.FullName := CashierObj.Get('full_name', '');
        Cashier.Nin := CashierObj.Get('nin', '');
        Cashier.KeyId := CashierObj.Get('key_id', '');
        Cashier.SignatureType := CashierObj.Get('signature_type', '');
        Cashier.CertificateEnd := AWebAPI.ParseDateTime(CashierObj.Get('certificate_end', ''));
        Cashier.Blocked := CashierObj.Get('blocked', False);
        Cashier.CreatedAt := AWebAPI.ParseDateTime(CashierObj.Get('created_at', ''));
        Cashier.UpdatedAt := AWebAPI.ParseDateTime(CashierObj.Get('updated_at', ''));
      end;
    end;

    // Парсимо cash_register з перевіркою на тип
    if (JsonData.Find('cash_register') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('cash_register')].JSONType = jtObject) then
    begin
      CashRegObj := JsonData.Objects['cash_register'];
      if Assigned(CashRegObj) then
      begin
        CashRegister := TCashRegister.Create;
        CashRegister.Id := CashRegObj.Get('id', '');
        CashRegister.FiscalNumber := CashRegObj.Get('fiscal_number', '');
        CashRegister.Active := CashRegObj.Get('active', False);
        CashRegister.Number := CashRegObj.Get('number', '');
        CashRegister.CreatedAt := AWebAPI.ParseDateTime(CashRegObj.Get('created_at', ''));
        CashRegister.UpdatedAt := AWebAPI.ParseDateTime(CashRegObj.Get('updated_at', ''));
      end;
    end;

    // Парсимо custom_fields з перевіркою на тип
    if (JsonData.Find('custom_fields') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('custom_fields')].JSONType = jtObject) then
    begin
      CustomObj := JsonData.Objects['custom_fields'];
      if Assigned(CustomObj) then
      begin
        CustomFields := TReceiptCustomFields.Create;
        CustomFields.ReceiptNumber := CustomObj.Get('receipt_number', '');
        CustomFields.CustomerName := CustomObj.Get('customer_name', '');
        CustomFields.CustomerAddress := CustomObj.Get('customer_address', '');
        CustomFields.ContractNumber := CustomObj.Get('contract_number', '');
        CustomFields.ContractDate := AWebAPI.ParseDateTime(CustomObj.Get('contract_date', ''));
        CustomFields.DocumentNumber := CustomObj.Get('document_number', '');
        CustomFields.DocumentDate := AWebAPI.ParseDateTime(CustomObj.Get('document_date', ''));
        CustomFields.AdditionalInfo := CustomObj.Get('additional_info', '');
        CustomFields.PaymentDetails := CustomObj.Get('payment_details', '');
        CustomFields.CashierTitle := CustomObj.Get('cashier_title', '');
        CustomFields.PreparedBy := CustomObj.Get('prepared_by', '');
        CustomFields.CashWithdrawalPurpose := CustomObj.Get('cash_withdrawal_purpose', '');
        CustomFields.CashWithdrawalRecipient := CustomObj.Get('cash_withdrawal_recipient', '');
        CustomFields.CashWithdrawalPayer := CustomObj.Get('cash_withdrawal_payer', '');
        CustomFields.CashWithdrawalSource := CustomObj.Get('cash_withdrawal_source', '');
        CustomFields.CashWithdrawalOrderNumber := CustomObj.Get('cash_withdrawal_order_number', '');
        CustomFields.CashWithdrawalOrderDate := AWebAPI.ParseDateTime(CustomObj.Get('cash_withdrawal_order_date', ''));
        CustomFields.CashWithdrawalBudgetCode := CustomObj.Get('cash_withdrawal_budget_code', '');
        CustomFields.CashWithdrawalBudgetPeriod := CustomObj.Get('cash_withdrawal_budget_period', '');
        CustomFields.CashWithdrawalDocumentType := CustomObj.Get('cash_withdrawal_document_type', '');
        CustomFields.CashWithdrawalTaxId := CustomObj.Get('cash_withdrawal_tax_id', '');
        CustomFields.CashWithdrawalTaxIdSeries := CustomObj.Get('cash_withdrawal_tax_id_series', '');
        CustomFields.CashWithdrawalTaxIdNumber := CustomObj.Get('cash_withdrawal_tax_id_number', '');
        CustomFields.CashWithdrawalTaxIdIssuedBy := CustomObj.Get('cash_withdrawal_tax_id_issued_by', '');
        CustomFields.CashWithdrawalTaxIdIssuedAt := AWebAPI.ParseDateTime(CustomObj.Get('cash_withdrawal_tax_id_issued_at', ''));
        CustomFields.CashWithdrawalRepresentative := CustomObj.Get('cash_withdrawal_representative', '');
        CustomFields.CashWithdrawalRepresentativeTaxId := CustomObj.Get('cash_withdrawal_representative_tax_id', '');
        CustomFields.CashWithdrawalRepresentativeTaxIdSeries := CustomObj.Get('cash_withdrawal_representative_tax_id_series', '');
        CustomFields.CashWithdrawalRepresentativeTaxIdNumber := CustomObj.Get('cash_withdrawal_representative_tax_id_number', '');
        CustomFields.CashWithdrawalRepresentativeTaxIdIssuedBy := CustomObj.Get('cash_withdrawal_representative_tax_id_issued_by', '');
        CustomFields.CashWithdrawalRepresentativeTaxIdIssuedAt := AWebAPI.ParseDateTime(CustomObj.Get('cash_withdrawal_representative_tax_id_issued_at', ''));
        CustomFields.CashWithdrawalRepresentativeDocument := CustomObj.Get('cash_withdrawal_representative_document', '');
        CustomFields.CashWithdrawalRepresentativeDocumentSeries := CustomObj.Get('cash_withdrawal_representative_document_series', '');
        CustomFields.CashWithdrawalRepresentativeDocumentNumber := CustomObj.Get('cash_withdrawal_representative_document_number', '');
        CustomFields.CashWithdrawalRepresentativeDocumentIssuedBy := CustomObj.Get('cash_withdrawal_representative_document_issued_by', '');
        CustomFields.CashWithdrawalRepresentativeDocumentIssuedAt := AWebAPI.ParseDateTime(CustomObj.Get('cash_withdrawal_representative_document_issued_at', ''));
      end;
    end;

    // Парсимо service_operations з перевіркою на тип
    if (JsonData.Find('service_operations') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('service_operations')].JSONType = jtArray) then
    begin
     ServiceArray := JsonData.Arrays['service_operations'];
     if Assigned(ServiceArray) then
      begin
       if not ParseServiceOperationsFromJSON(ServiceArray, AWebAPI) then
       begin
        AWebAPI.Log('ParseFromJSON: Помилка парсингу service_operations');
        // Продовжуємо обробку навіть якщо не вдалося розпарсити service_operations
       end;
      end;
    end
    else
    begin
     // Якщо service_operations відсутній або не є масивом, створюємо пустий масив
     SetLength(ServiceOperations, 0);
    end;

    // Парсимо signatures з перевіркою на тип з використанням універсальної функції
    if (JsonData.Find('signatures') <> nil) and
      (JsonData.Items[JsonData.IndexOfName('signatures')].JSONType = jtArray) then
    begin
      SignaturesArray := JsonData.Arrays['signatures'];
      if Assigned(SignaturesArray) then
       begin
        SetLength(Self.Signatures, SignaturesArray.Count);
        for I := 0 to SignaturesArray.Count - 1 do
        begin
          if SignaturesArray.Items[I].JSONType = jtObject then
           begin
            try
             // Використовуємо універсальну функцію для парсингу підпису
             Self.Signatures[I] := AWebAPI.ParseSignatureFromJSON(SignaturesArray.Objects[I]);
            except
             on E: Exception do
             begin
              AWebAPI.Log('ParseFromJSON: Помилка парсингу підпису ' + IntToStr(I) + ': ' + E.Message);
              Self.Signatures[I] := TSignature.Create; // Створюємо пустий об'єкт
             end;
            end;
            end
            else
            begin
             // Якщо елемент масиву не об'єкт, створюємо пустий підпис
             AWebAPI.Log('ParseFromJSON: Елемент signatures[' + IntToStr(I) + '] не є об`єктом JSON');
             Self.Signatures[I] := TSignature.Create;
            end;
        end;
       end;
    end
    else
    begin
     // Якщо signatures відсутній або не є масивом, створюємо пустий масив
     SetLength(Self.Signatures, 0);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      // Логування помилки парсингу
      AWebAPI.Log('Error parsing JSON response: ' + E.Message);
      Result := False;
    end;

  end;
  finally
    // Цей блок виконується завжди, незалежно від помилки
    if Assigned(JsonData) then
      JsonData.Free;
    if Assigned(JsonParser) then
      JsonParser.Free;
  end;
end;



procedure TReceiptWebAPI.SetLogProcedure(ALogProcedure: TLogProcedure);
begin
  FLogProcedure := ALogProcedure;
end;

procedure TReceiptWebAPI.Log(const AMessage: string);
begin
  if Assigned(FLogProcedure) then
    FLogProcedure(AMessage);
end;

function TReceiptWebAPI.GenerateUUID: string;
var
  I: Integer;
  Bytes: array[0..15] of Byte;
begin
  // Використовуємо вбудований генератор UUID, якщо він доступний.
  // Якщо ні, використовуємо більш простий метод на основі Random.
  // Примітка: для криптографічної безпеки потрібен інший підхід.
  for I := 0 to 15 do
    Bytes[I] := Random(256);

  Bytes[6] := (Bytes[6] and $0F) or $40; // Версія 4
  Bytes[8] := (Bytes[8] and $3F) or $80; // Варіант 1

  Result := LowerCase(Format('%.2x%.2x%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x', [
    Bytes[0], Bytes[1], Bytes[2], Bytes[3],
    Bytes[4], Bytes[5],
    Bytes[6], Bytes[7],
    Bytes[8], Bytes[9],
    Bytes[10], Bytes[11], Bytes[12], Bytes[13], Bytes[14], Bytes[15]
  ]));
end;

function TReceiptWebAPI.IsValidUUID(const UUID: string): Boolean;
var
  Regex: TRegExpr;
begin
  Regex := TRegExpr.Create('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  try
    Result := Regex.Exec(UUID);
  finally
    Regex.Free;
  end;
end;

function TReceiptWebAPI.DiscountTypeToString(ADiscountType: TDiscountType): string;
begin
  case ADiscountType of
    dtDiscount: Result := 'DISCOUNT';
    dtExtraCharge: Result := 'EXTRA_CHARGE';
  else
    Result := 'DISCOUNT';
  end;
end;

function TReceiptWebAPI.DiscountModeToString(ADiscountMode: TDiscountMode): string;
begin
  case ADiscountMode of
    dmValue: Result := 'VALUE';
    dmPercent: Result := 'PERCENT';
  else
    Result := 'PERCENT';
  end;
end;

function TReceiptWebAPI.PaymentTypeToString(APaymentType: TPaymentType): string;
begin
  case APaymentType of
    ptCash: Result := 'CASH';
    ptCashless: Result := 'CASHLESS';
    ptCard: Result := 'CASHLESS'; // Картка теж безготівка
  else
    Result := 'CASH';
  end;
end;

function TReceiptWebAPI.StringToTransactionStatus(const Status: string): TTransactionStatus;
begin
  if Status = 'DONE' then
    Result := tsDone
  else if Status = 'ERROR' then
    Result := tsError
  else
    Result := tsPending;
end;

function TReceiptWebAPI.StringToReceiptStatus(const Status: string): TReceiptStatus;
begin
  if Status = 'CREATED' then
    Result := rsCreated
  else if Status = 'PENDING' then
    Result := rsPending
  else if Status = 'DONE' then
    Result := rsDone
  else if Status = 'DELIVERED' then
    Result := rsDelivered  // ← НОВИЙ СТАТУС
  else if Status = 'ERROR' then
    Result := rsError
  else
    Result := rsCreated;
end;

function TReceiptWebAPI.ParseDateTime(const DateTimeStr: string): TDateTime;
var
  Year, Month, Day, Hour, Minute, Second, MilliSecond: Word;
  CleanStr: string;
  PosT, PosDot, PosPlus, PosMinus: Integer;
begin
  Result := 0;
  if DateTimeStr = '' then Exit;

  try
    // Видаляємо часову зону та мілісекунди якщо потрібно
    CleanStr := DateTimeStr;

    // Знаходимо позиції спеціальних символів
    PosT := Pos('T', CleanStr);
    PosDot := Pos('.', CleanStr);
    PosPlus := Pos('+', CleanStr);
    PosMinus := Pos('-', CleanStr); // для негативних зон

    // Обрізаємо часову зону
    if PosPlus > 0 then
      CleanStr := Copy(CleanStr, 1, PosPlus - 1)
    else if (PosMinus > 0) and (PosMinus > PosT) then // мінус після T (не в даті)
      CleanStr := Copy(CleanStr, 1, PosMinus - 1);

    // Обрізаємо мілісекунди
    if PosDot > 0 then
      CleanStr := Copy(CleanStr, 1, PosDot - 1) + Copy(CleanStr, PosDot + 4, MaxInt);

    // Парсимо основні компоненти
    Year := StrToInt(Copy(CleanStr, 1, 4));
    Month := StrToInt(Copy(CleanStr, 6, 2));
    Day := StrToInt(Copy(CleanStr, 9, 2));

    // Години, хвилини, секунди (якщо є)
    if PosT > 0 then
    begin
      Hour := StrToInt(Copy(CleanStr, 12, 2));
      Minute := StrToInt(Copy(CleanStr, 15, 2));
      Second := StrToInt(Copy(CleanStr, 18, 2));
    end
    else
    begin
      Hour := 0;
      Minute := 0;
      Second := 0;
    end;

    MilliSecond := 0;

    Result := EncodeDateTime(Year, Month, Day, Hour, Minute, Second, MilliSecond);

  except
    on E: EConvertError do
    begin
      Log('ParseDateTime convert error: ' + E.Message + ' for: ' + DateTimeStr);
      Result := 0;
    end;
    on E: Exception do
    begin
      Log('ParseDateTime error: ' + E.Message + ' for: ' + DateTimeStr);
      Result := 0;
    end;
  end;
end;

function TReceiptWebAPI.ExecuteCurlCommand(const ACommand: string; const AProcedureName, AEndpoint: string; out AResponse: string): Boolean;
var
  Process: TProcess;
  OutputStream, ErrorStream: TStringStream;
  BytesRead: LongInt;
  Buffer: array[0..2047] of Byte;
  FullCommand: string;
begin
  Result := False;
  AResponse := '';
  Process := TProcess.Create(nil);
  OutputStream := TStringStream.Create('');
  ErrorStream := TStringStream.Create('');

  try
    // 1. Логування назви процедури, основної частини запиту
    Log(Format('.[%s] %s ', [AProcedureName, AEndpoint]));

    FullCommand := 'curl -a ' + ACommand;
    Log('Executing curl command: ' + FullCommand); // Додайте цей рядок

    Process.Executable := 'curl';
    //Process.Parameters.DelimitedText := ACommand;
    Process.Parameters.DelimitedText := '-s ' + ACommand; // Додано -s на початку
    Process.Options := [poUsePipes, poNoConsole, poStderrToOutPut];
    Process.Execute;

    // Читаємо вивід процесу
    while Process.Running or (Process.Output.NumBytesAvailable > 0) do
    begin
      BytesRead := Process.Output.Read(Buffer, SizeOf(Buffer));
      if BytesRead > 0 then
        OutputStream.Write(Buffer, BytesRead);
    end;

    AResponse := OutputStream.DataString;

    // Додаємо логування результату
    Log('Curl exit status: ' + IntToStr(Process.ExitStatus));
    //Log('Curl response: ' + Copy(AResponse, 1, 500)); // Перші 500 символів
    Log('Raw JSON response: ' + Copy(AResponse, 1, 1000));
    Result := Process.ExitStatus = 0;

  except
    on E: Exception do
    begin
      AResponse := 'Exception in ExecuteCurlCommand: ' + E.Message;
      Log('ERROR in ExecuteCurlCommand: ' + E.Message);
    end;
  end;

  Process.Free;
  OutputStream.Free;
  ErrorStream.Free;
end;



function TReceiptWebAPI.BuildJsonData(AReceipt: TReceipt): TJSONObject;
var
  JsonData: TJSONObject;
  GoodsArray, DiscountsArray, BonusesArray, PaymentsArray, TaxesArray, EmailsArray: TJSONArray;
  GoodItem, DiscountItem, BonusItem, PaymentItem, TaxItem: TJSONObject;
  GoodDiscountItem: TJSONObject;
  DeliveryObj: TJSONObject;
  CustomObj: TJSONObject;
  I, J: Integer;
begin
  JsonData := TJSONObject.Create;

  try
    // Додаємо основні поля
    JsonData.Add('id', AReceipt.Id);
    JsonData.Add('type', ReceiptTypeToString(AReceipt.ReceiptType));
    JsonData.Add('cashier_name', AReceipt.CashierName);
    JsonData.Add('departament', AReceipt.Departament);
    JsonData.Add('rounding', AReceipt.Rounding);
    JsonData.Add('header', AReceipt.Header);
    JsonData.Add('footer', AReceipt.Footer);
    JsonData.Add('barcode', AReceipt.Barcode);
    JsonData.Add('order_id', AReceipt.OrderId);
    JsonData.Add('related_receipt_id', AReceipt.RelatedReceiptId);
    JsonData.Add('previous_receipt_id', AReceipt.PreviousReceiptId);
    JsonData.Add('technical_return', AReceipt.TechnicalReturn);
    JsonData.Add('is_pawnshop', AReceipt.IsPawnshop);

    // Додаємо суми (обов'язкові поля)
    JsonData.Add('sum', AReceipt.Sum);
    JsonData.Add('total_sum', AReceipt.TotalSum);
    JsonData.Add('total_payment', AReceipt.TotalPayment);
    JsonData.Add('total_rest', AReceipt.TotalRest);
    JsonData.Add('rest', AReceipt.Rest);

    // Додаємо контекст
    if AReceipt.Context <> '' then
      JsonData.Add('context', AReceipt.Context);

    // Додаємо податки на рівні чека
    if Length(AReceipt.Taxes) > 0 then
    begin
      TaxesArray := TJSONArray.Create;
      try
        for I := 0 to High(AReceipt.Taxes) do
        begin
          if Assigned(AReceipt.Taxes[I]) then
          begin
            TaxItem := TJSONObject.Create;
            try
              TaxItem.Add('code', AReceipt.Taxes[I].Code);
              TaxItem.Add('rate', AReceipt.Taxes[I].Rate);
              TaxItem.Add('value', AReceipt.Taxes[I].Value);
              if AReceipt.Taxes[I].LabelText <> '' then
                TaxItem.Add('label', AReceipt.Taxes[I].LabelText);
              if AReceipt.Taxes[I].Symbol <> '' then
                TaxItem.Add('symbol', AReceipt.Taxes[I].Symbol);

              TaxesArray.Add(TaxItem);
            except
              TaxItem.Free;
              raise;
            end;
          end;
        end;
        JsonData.Add('taxes', TaxesArray);
      except
        TaxesArray.Free;
        raise;
      end;
    end;

    // Додаємо офлайн-поля
    if AReceipt.IsOffline then
    begin
      JsonData.Add('offline_mode', True);
      JsonData.Add('offline_sequence_number', AReceipt.OfflineSequenceNumber);
    end;

    // Додаємо масив товарів
    GoodsArray := TJSONArray.Create;
    try
      for I := 0 to High(AReceipt.Goods) do
      begin
        if Assigned(AReceipt.Goods[I]) then
        begin
          GoodItem := TJSONObject.Create;
          try
            GoodItem.Add('good_id', AReceipt.Goods[I].GoodId);
            GoodItem.Add('quantity', AReceipt.Goods[I].Quantity);
            GoodItem.Add('is_return', AReceipt.Goods[I].IsReturn);
            GoodItem.Add('is_winnings_payout', AReceipt.Goods[I].IsWinningsPayout);
            GoodItem.Add('total_sum', AReceipt.Goods[I].TotalSum);
            GoodItem.Add('sum', AReceipt.Goods[I].Sum);

            // Додаємо інформацію про товар
            if Assigned(AReceipt.Goods[I].Good) then
            begin
              GoodItem.Add('good', TJSONObject.Create([
                'code', AReceipt.Goods[I].Good.Code,
                'name', AReceipt.Goods[I].Good.Name,
                'price', AReceipt.Goods[I].Good.Price
              ]));
            end;

            // Додаємо знижки на товар
            if Length(AReceipt.Goods[I].Discounts) > 0 then
            begin
              DiscountsArray := TJSONArray.Create;
              try
                for J := 0 to High(AReceipt.Goods[I].Discounts) do
                begin
                  if Assigned(AReceipt.Goods[I].Discounts[J]) then
                  begin
                    GoodDiscountItem := TJSONObject.Create;
                    try
                      GoodDiscountItem.Add('type', DiscountTypeToString(AReceipt.Goods[I].Discounts[J].DiscountType));
                      GoodDiscountItem.Add('mode', DiscountModeToString(AReceipt.Goods[I].Discounts[J].Mode));
                      GoodDiscountItem.Add('value', AReceipt.Goods[I].Discounts[J].Value);
                      GoodDiscountItem.Add('name', AReceipt.Goods[I].Discounts[J].Name);
                      GoodDiscountItem.Add('privilege', AReceipt.Goods[I].Discounts[J].Privilege);

                      DiscountsArray.Add(GoodDiscountItem);
                    except
                      GoodDiscountItem.Free;
                      raise;
                    end;
                  end;
                end;
                GoodItem.Add('discounts', DiscountsArray);
              except
                DiscountsArray.Free;
                raise;
              end;
            end;

            GoodsArray.Add(GoodItem);
          except
            GoodItem.Free;
            raise;
          end;
        end;
      end;
      JsonData.Add('goods', GoodsArray);
    except
      GoodsArray.Free;
      raise;
    end;

     // Додаємо доставку
    if Assigned(AReceipt.Delivery) then
    begin
      DeliveryObj := TJSONObject.Create;
      try
        if AReceipt.Delivery.Email <> '' then
          DeliveryObj.Add('email', AReceipt.Delivery.Email);
        if AReceipt.Delivery.Phone <> '' then
          DeliveryObj.Add('phone', AReceipt.Delivery.Phone);
        if Length(AReceipt.Delivery.Emails) > 0 then
        begin
          EmailsArray := TJSONArray.Create;
          try
            for I := 0 to High(AReceipt.Delivery.Emails) do
              EmailsArray.Add(AReceipt.Delivery.Emails[I]);
            DeliveryObj.Add('emails', EmailsArray);
          except
            EmailsArray.Free;
            raise;
          end;
        end;

        JsonData.Add('delivery', DeliveryObj);
      except
        DeliveryObj.Free;
        raise;
      end;
    end;

    // Додаємо знижки на весь чек
    if Length(AReceipt.Discounts) > 0 then
    begin
      DiscountsArray := TJSONArray.Create;
      try
        for I := 0 to High(AReceipt.Discounts) do
        begin
          if Assigned(AReceipt.Discounts[I]) then
          begin
            DiscountItem := TJSONObject.Create;
            try
              DiscountItem.Add('type', DiscountTypeToString(AReceipt.Discounts[I].DiscountType));
              DiscountItem.Add('mode', DiscountModeToString(AReceipt.Discounts[I].Mode));
              DiscountItem.Add('value', AReceipt.Discounts[I].Value);
              DiscountItem.Add('name', AReceipt.Discounts[I].Name);
              DiscountItem.Add('privilege', AReceipt.Discounts[I].Privilege);
              DiscountItem.Add('sum', AReceipt.Discounts[I].Sum);

              DiscountsArray.Add(DiscountItem);
            except
              DiscountItem.Free;
              raise;
            end;
          end;
        end;
        JsonData.Add('discounts', DiscountsArray);
      except
        DiscountsArray.Free;
        raise;
      end;
    end;

    // Додаємо бонуси
    if Length(AReceipt.Bonuses) > 0 then
    begin
      BonusesArray := TJSONArray.Create;
      try
        for I := 0 to High(AReceipt.Bonuses) do
        begin
          if Assigned(AReceipt.Bonuses[I]) then
          begin
            BonusItem := TJSONObject.Create;
            try
              BonusItem.Add('bonus_card', AReceipt.Bonuses[I].BonusCard);
              BonusItem.Add('value', AReceipt.Bonuses[I].Value);
              BonusItem.Add('additional_info', AReceipt.Bonuses[I].AdditionalInfo);

              BonusesArray.Add(BonusItem);
            except
              BonusItem.Free;
              raise;
            end;
          end;
        end;
        JsonData.Add('bonuses', BonusesArray);
      except
        BonusesArray.Free;
        raise;
      end;
    end;

    // Додаємо оплати
    if Length(AReceipt.Payments) > 0 then
    begin
      PaymentsArray := TJSONArray.Create;
      try
        for I := 0 to High(AReceipt.Payments) do
        begin
          if Assigned(AReceipt.Payments[I]) then
          begin
            PaymentItem := TJSONObject.Create;
            try
              PaymentItem.Add('type', PaymentTypeToString(AReceipt.Payments[I].PaymentType));
              PaymentItem.Add('label', AReceipt.Payments[I].LabelText);
              PaymentItem.Add('value', AReceipt.Payments[I].Value);
              PaymentItem.Add('code', AReceipt.Payments[I].Code);
              PaymentItem.Add('pawnshop_is_return', AReceipt.Payments[I].PawnshopIsReturn);

              if AReceipt.Payments[I].ProviderType <> '' then
                PaymentItem.Add('provider_type', AReceipt.Payments[I].ProviderType);
              if AReceipt.Payments[I].Commission > 0 then
                PaymentItem.Add('commission', AReceipt.Payments[I].Commission);
              if AReceipt.Payments[I].CardMask <> '' then
                PaymentItem.Add('card_mask', AReceipt.Payments[I].CardMask);
              if AReceipt.Payments[I].BankName <> '' then
                PaymentItem.Add('bank_name', AReceipt.Payments[I].BankName);
              if AReceipt.Payments[I].AuthCode <> '' then
                PaymentItem.Add('auth_code', AReceipt.Payments[I].AuthCode);
              if AReceipt.Payments[I].RRN <> '' then
                PaymentItem.Add('rrn', AReceipt.Payments[I].RRN);
              if AReceipt.Payments[I].PaymentSystem <> '' then
                PaymentItem.Add('payment_system', AReceipt.Payments[I].PaymentSystem);
              if AReceipt.Payments[I].OwnerName <> '' then
                PaymentItem.Add('owner_name', AReceipt.Payments[I].OwnerName);
              if AReceipt.Payments[I].Terminal <> '' then
                PaymentItem.Add('terminal', AReceipt.Payments[I].Terminal);
              if AReceipt.Payments[I].AcquirerAndSeller <> '' then
                PaymentItem.Add('acquirer_and_seller', AReceipt.Payments[I].AcquirerAndSeller);
              if AReceipt.Payments[I].ReceiptNo <> '' then
                PaymentItem.Add('receipt_no', AReceipt.Payments[I].ReceiptNo);

              PaymentItem.Add('signature_required', AReceipt.Payments[I].SignatureRequired);

              if AReceipt.Payments[I].TapxphoneTerminal <> '' then
                PaymentItem.Add('tapxphone_terminal', AReceipt.Payments[I].TapxphoneTerminal);

              PaymentsArray.Add(PaymentItem);
            except
              PaymentItem.Free;
              raise;
            end;
          end;
        end;
        JsonData.Add('payments', PaymentsArray);
      except
        PaymentsArray.Free;
        raise;
      end;
    end;

    // Додаємо кастомні налаштування
    if Assigned(AReceipt.Custom) then
    begin
      CustomObj := TJSONObject.Create;
      try
        if AReceipt.Custom.HtmlGlobalHeader <> '' then
          CustomObj.Add('html_global_header', AReceipt.Custom.HtmlGlobalHeader);
        if AReceipt.Custom.HtmlGlobalFooter <> '' then
          CustomObj.Add('html_global_footer', AReceipt.Custom.HtmlGlobalFooter);
        if AReceipt.Custom.HtmlBodyStyle <> '' then
          CustomObj.Add('html_body_style', AReceipt.Custom.HtmlBodyStyle);
        if AReceipt.Custom.HtmlReceiptStyle <> '' then
          CustomObj.Add('html_receipt_style', AReceipt.Custom.HtmlReceiptStyle);
        if AReceipt.Custom.HtmlRulerStyle <> '' then
          CustomObj.Add('html_ruler_style', AReceipt.Custom.HtmlRulerStyle);
        if AReceipt.Custom.HtmlLightBlockStyle <> '' then
          CustomObj.Add('html_light_block_style', AReceipt.Custom.HtmlLightBlockStyle);
        if AReceipt.Custom.TextGlobalHeader <> '' then
          CustomObj.Add('text_global_header', AReceipt.Custom.TextGlobalHeader);
        if AReceipt.Custom.TextGlobalFooter <> '' then
          CustomObj.Add('text_global_footer', AReceipt.Custom.TextGlobalFooter);

        JsonData.Add('custom', CustomObj);
      except
        CustomObj.Free;
        raise;
      end;
    end;

    Result := JsonData;

  except
    on E: Exception do
    begin
      // Логування помилки
      Log('BuildJsonData: Помилка створення JSON: ' + E.Message);

      // Звільнення пам'яті
      if Assigned(JsonData) then
        FreeAndNil(JsonData);

      // Перевикидання винятку
      raise;
    end;
  end;
end;


function TReceiptWebAPI.BuildJsonDataCorrected(AReceipt: TReceipt): TJSONObject;
var
  JsonData: TJSONObject;
  GoodsArray: TJSONArray;
  PaymentsArray: TJSONArray;
  GoodItem: TJSONObject;
  GoodData: TJSONObject;
  PaymentItem: TJSONObject;
  TaxArray: TJSONArray;
  i: Integer;
  PaymentTypeStr: string;
begin
  JsonData := TJSONObject.Create;

  try
    // ОБОВ'ЯЗКОВІ ПОЛЯ згідно з документацією
    JsonData.Add('id', AReceipt.Id);
    JsonData.Add('cashier_name', AReceipt.CashierName);
    JsonData.Add('departament', AReceipt.Departament);

    // OrderId - string (не обов'язково UUID)
    if AReceipt.OrderId <> '' then
      JsonData.Add('order_id', AReceipt.OrderId);

    // Goods array
    GoodsArray := TJSONArray.Create;
    for i := 0 to High(AReceipt.Goods) do
    begin
      if Assigned(AReceipt.Goods[i]) and Assigned(AReceipt.Goods[i].Good) then
      begin
        GoodItem := TJSONObject.Create;

        // Good object
        GoodData := TJSONObject.Create;
        GoodData.Add('code', AReceipt.Goods[i].Good.Code);
        GoodData.Add('name', AReceipt.Goods[i].Good.Name);
        GoodData.Add('price', AReceipt.Goods[i].Good.Price);

        // Barcode - опціонально
        if AReceipt.Goods[i].Good.Barcode <> '' then
          GoodData.Add('barcode', AReceipt.Goods[i].Good.Barcode);

        // Tax codes
        if Length(AReceipt.Goods[i].Good.TaxCodes) > 0 then
        begin
          TaxArray := TJSONArray.Create;
          TaxArray.Add(AReceipt.Goods[i].Good.TaxCodes[0]); // Беремо перший податок
          GoodData.Add('tax_codes', TaxArray);
        end;

        GoodItem.Add('good', GoodData);

        // Good item fields
        GoodItem.Add('good_id', AReceipt.Goods[i].GoodId);
        GoodItem.Add('quantity', AReceipt.Goods[i].Quantity);
        GoodItem.Add('sum', AReceipt.Goods[i].Sum);
        GoodItem.Add('is_return', AReceipt.Goods[i].IsReturn);

        GoodsArray.Add(GoodItem);
      end;
    end;
    JsonData.Add('goods', GoodsArray);

    // Payments array
    PaymentsArray := TJSONArray.Create;
    for i := 0 to High(AReceipt.Payments) do
    begin
      if Assigned(AReceipt.Payments[i]) then
      begin
        PaymentItem := TJSONObject.Create;

        // Конвертація типу оплати в string
        case AReceipt.Payments[i].PaymentType of
          ptCash: PaymentTypeStr := 'CASH';
          ptCashless: PaymentTypeStr := 'CASHLESS';
          // ptCard: PaymentTypeStr := 'CARD'; // Закоментуйте, якщо ptCard не існує
        else
          PaymentTypeStr := 'CASH'; // За замовчуванням
        end;

        PaymentItem.Add('type', PaymentTypeStr);
        PaymentItem.Add('value', AReceipt.Payments[i].Value);
        PaymentItem.Add('label', AReceipt.Payments[i].LabelText);
        PaymentItem.Add('code', AReceipt.Payments[i].Code);

        PaymentsArray.Add(PaymentItem);
      end;
    end;
    JsonData.Add('payments', PaymentsArray);

    // Суми
    JsonData.Add('total_sum', AReceipt.TotalSum);
    JsonData.Add('total_payment', AReceipt.TotalPayment);

    // Rounding
    if AReceipt.Rounding then
      JsonData.Add('rounding', AReceipt.Rounding);

    // Header/Footer - опціонально
    if AReceipt.Header <> '' then
      JsonData.Add('header', AReceipt.Header);
    if AReceipt.Footer <> '' then
      JsonData.Add('footer', AReceipt.Footer);

    Log('=== ФІНАЛЬНИЙ JSON ЗГІДНО З ДОКУМЕНТАЦІЄЮ ===');
    Log(JsonData.AsJSON);
    Log('============================================');

    Result := JsonData;

  except
    on E: Exception do
    begin
      Log('Помилка побудови JSON: ' + E.Message);
      JsonData.Free;
      raise;
    end;
  end;
end;


function TReceiptWebAPI.BuildAuthJsonData: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    // ВИПРАВЛЕНО: Використовуємо 'login' замість 'username'
    Result.Add('login', FUsername);
    Result.Add('password', FPassword);
    // Видалено: client_name та client_version (вони передаються в заголовках)
  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;

function TReceiptWebAPI.ParseAuthResponse(const JSONString: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  ExpiresIn: Integer;
begin
  Result := False;
  JsonData := nil;
  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);

  try
    JsonData := JsonParser.Parse as TJSONObject;

    // Отримуємо всі поля з відповіді
    FAuthInfo.Token := JsonData.Get('access_token', '');
    FAuthInfo.TokenType := JsonData.Get('token_type', 'bearer');
    FAuthInfo.RefreshToken := JsonData.Get('refresh_token', '');

    // Коректно обчислюємо час закінчення
    ExpiresIn := JsonData.Get('expires_in', 86400); // 24 години за замовчуванням
    FAuthInfo.ExpiresAt := Now + (ExpiresIn * OneSecond);

    //FAuthToken := FAuthInfo.Token; // Для зворотньої сумісності

    Result := FAuthInfo.Token <> '';

    if Result then
      Log('Token successfully parsed. Expires: ' + DateTimeToStr(FAuthInfo.ExpiresAt))
    else
      Log('Failed to parse token from response: ' + JSONString);

  except
    on E: Exception do
    begin
      Log('Exception in ParseAuthResponse: ' + E.Message);
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.IsTokenValid: Boolean;
begin
  // Перевіряємо, чи токен існує і не прострочений (з запасом 5 хвилин)
  Result := Assigned(FAuthInfo) and
         (FAuthInfo.Token <> '') and
         (FAuthInfo.ExpiresAt > Now + (5 * OneMinute));

  //Result := (FAuthInfo.Token <> '') and (FAuthInfo.ExpiresAt > Now + (5 * OneMinute));
  //  Result := (FAccessToken <> '') and (FTokenExpiration > Now);
  if not Result then
    Log('IsTokenValid: Токен недійсний (Token=' + FAuthInfo.Token +
        ', Expires At=' + DateTimeToStr(FAuthInfo.ExpiresAt) + ')');

end;




function TReceiptWebAPI.CreateGood(ACode, AName: string; APrice: Integer): TGood;
begin
  Result := TGood.Create;
  Result.Code := ACode;
  Result.Name := AName;
  Result.Price := APrice;
end;

function TReceiptWebAPI.CreateGoodItem(AGood: TGood; AQuantity: Integer): TGoodItem;
begin
  Result := TGoodItem.Create;
  Result.Good := AGood;
  Result.GoodId := GenerateUUID;
  Result.Quantity := AQuantity;
  Result.IsReturn := False;
  Result.IsWinningsPayout := False;
end;

function TReceiptWebAPI.CreatePayment(APaymentType: TPaymentType; AValue: Integer): TPayment;
begin
  Result := TPayment.Create;
  Result.PaymentType := APaymentType;
  Result.Value := AValue;
end;

function TReceiptWebAPI.CreateDelivery(AEmail, APhone: string): TDelivery;
begin
  Result := TDelivery.Create;
  Result.Email := AEmail;
  Result.Phone := APhone;
end;


function TReceiptWebAPI.ParseCashRegisterStatus(const JSONString: string;
  out ACashRegisterStatus: TCashRegisterStatus): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
begin
  //Log(JSONString);
  Result := False;
  ACashRegisterStatus := nil;
  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);

  try
    JsonData := JsonParser.Parse as TJSONObject;

    if JsonData.Get('id', '') = '' then
    begin
      Log('ParseCashRegisterStatus: Missing id field');
      Exit(False);
    end;

    ACashRegisterStatus := TCashRegisterStatus.Create;

    // Заповнюємо основні поля
    ACashRegisterStatus.Id := JsonData.Get('id', '');
    ACashRegisterStatus.FiscalNumber := JsonData.Get('fiscal_number', '');
    ACashRegisterStatus.Active := JsonData.Get('active', False);
    ACashRegisterStatus.Number := JsonData.Get('number', '');
    ACashRegisterStatus.CreatedAt := ParseDateTime(JsonData.Get('created_at', ''));
    ACashRegisterStatus.UpdatedAt := ParseDateTime(JsonData.Get('updated_at', ''));
    ACashRegisterStatus.LastZReportDate := ParseDateTime(JsonData.Get('last_z_report_date', ''));
    // НОВІ ПОЛЯ:
    ACashRegisterStatus.OfflineMode := JsonData.Get('offline_mode', False);
    ACashRegisterStatus.StayOffline := JsonData.Get('stay_offline', False);
    ACashRegisterStatus.IsTest := JsonData.Get('is_test', False);

    // Статус зміни за замовчуванням
    ACashRegisterStatus.ShiftStatus := 'CLOSED';

    // Спроба отримати інформацію про зміну (якщо вона є)
    try
      if (JsonData.Find('shift') <> nil) and
         (JsonData.Items[JsonData.IndexOfName('shift')].JSONType <> jtNull) then
      begin
        with JsonData.Objects['shift'] do
        begin
          ACashRegisterStatus.ShiftStatus := Get('status', 'CLOSED');
          ACashRegisterStatus.ShiftOpenedAt := ParseDateTime(Get('opened_at', ''));
          ACashRegisterStatus.ShiftClosedAt := ParseDateTime(Get('closed_at', ''));
          ACashRegisterStatus.CurrentShiftNumber := Get('serial', 0);
        end;
      end;
    except
      on E: Exception do
      begin
        // Ігноруємо помилки парсингу shift - воно може бути null
        Log('Shift info not available or invalid: ' + E.Message);
      end;
    end;

    Result := True;

  except
    on E: Exception do
    begin
      FreeAndNil(ACashRegisterStatus);
      Log('ParseCashRegisterStatus fatal error: ' + E.Message);
      Result := False;
    end;
  end;
end;




function TReceiptWebAPI.GetCashRegisterStatusCurl(const ACashRegisterId: string; out AResponse: string; out ACashRegisterStatus: TCashRegisterStatus): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';
  ACashRegisterStatus := nil;

  // Перевіряємо чи токен дійсний, якщо ні - оновлюємо
  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  // Перевіряємо вхідні параметри
  if ACashRegisterId = '' then
  begin
    AResponse := 'Cash register ID is empty';
    Exit;
  end;

  try
    // Формуємо curl команду
    //Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/cash-registers/%s"',
    //  [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, ACashRegisterId]);
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/cash-registers/%s"',
         [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, ACashRegisterId]);

    // Виконуємо curl команду
    Result := ExecuteCurlCommand(Command,'GetCashRegisterStatusCurl' , 'GET /api/v1/cash-registers/',AResponse);

    // Парсимо відповідь

      if Result then
      begin
        Log('Отримано відповідь сервера, парсимо...');
        Result := ParseCashRegisterStatus(AResponse, ACashRegisterStatus);

        // Після успішного отримання статусу каси
        if Result and Assigned(ACashRegisterStatus) then
        begin
          // ЗБЕРІГАЄМО ID КАСИ ДЛЯ ПОДАЛЬШИХ ОПЕРАЦІЙ (якщо ще не встановлено або змінився)
          if (FCurrentCashRegisterId = '') or (FCurrentCashRegisterId <> ACashRegisterStatus.Id) then
          begin
            FCurrentCashRegisterId := ACashRegisterStatus.Id;
            Log('Встановлено ID каси: ' + FCurrentCashRegisterId);
          end
          else
          begin
            Log('ID каси вже встановлено: ' + FCurrentCashRegisterId);
          end;
        end;

        if Result then
          Log('Парсинг статусу каси успішний')
        else
          Log('Помилка парсингу статусу каси');
      end
      else
      begin
        Log('Помилка виконання curl команди: ' + AResponse);
      end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.ParseShiftStatus(const JSONString: string; out AShiftStatus: TShiftStatus): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  BalanceObj: TJSONObject;
  I: Integer;
  SignaturesArray: TJSONArray;
begin
  Result := False;
  AShiftStatus := nil;

  // Спочатку перевіряємо, чи це помилка або успішна відповідь
  if Pos('"message":"', JSONString) > 0 then
  begin
    // Якщо є поле message, це може бути помилка
    if (Pos('Помилка валідації', JSONString) > 0) or
       (Pos('error', LowerCase(JSONString)) > 0) or
       (Pos('detail', JSONString) > 0) then
    begin
      Log('ParseShiftStatus: Відповідь містить помилку: ' + Copy(JSONString, 1, 200));
      Exit(False);
    end;
  end;

  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);
  try
    JsonData := JsonParser.Parse as TJSONObject;

    // Додаткова перевірка на наявність поля статусу
    if (JsonData.Get('status', '') = '') and (JsonData.Get('id', '') = '') then
    begin
      Log('ParseShiftStatus: Відповідь не містить обовʼязкових полів (status, id)');
      Exit(False);
    end;

    AShiftStatus := TShiftStatus.Create;

    // Парсимо основні поля
    AShiftStatus.Id := JsonData.Get('id', '');
    AShiftStatus.Status := JsonData.Get('status', '');
    AShiftStatus.Serial := JsonData.Get('serial', 0);
    AShiftStatus.ZReport := JsonData.Get('z_report', '');
    AShiftStatus.OpenedAt := ParseDateTime(JsonData.Get('opened_at', ''));
    AShiftStatus.ClosedAt := ParseDateTime(JsonData.Get('closed_at', ''));
    AShiftStatus.InitialTransactionId := JsonData.Get('initial_transaction_id', '');
    AShiftStatus.ClosingTransactionId := JsonData.Get('closing_transaction_id', '');
    AShiftStatus.CreatedAt := ParseDateTime(JsonData.Get('created_at', ''));
    AShiftStatus.UpdatedAt := ParseDateTime(JsonData.Get('updated_at', ''));
    AShiftStatus.EmergencyClose := JsonData.Get('emergency_close', False);
    AShiftStatus.EmergencyCloseDetails := JsonData.Get('emergency_close_details', '');
    AShiftStatus.CashRegisterId := JsonData.Get('cash_register_id', '');
    AShiftStatus.CashierId := JsonData.Get('cashier_id', '');

    // ===== ПОЧАТОК: НОВИЙ КОД ДЛЯ ПАРСИНГУ BALANCE =====
    AShiftStatus.Balance := TBalanceInfo.Create; // Створюємо об'єкт за замовчуванням

    // Перевіряємо, чи існує об'єкт "balance" у відповіді
    if (JsonData.Find('balance') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('balance')].JSONType = jtObject) then
    begin
      BalanceObj := JsonData.Objects['balance'];
      // Заповнюємо поля BalanceInfo, використовуючи значення за замовчуванням (0), якщо поля немає
      AShiftStatus.Balance.Initial := BalanceObj.Get('initial', 0);
      AShiftStatus.Balance.Balance := BalanceObj.Get('balance', 0);
      AShiftStatus.Balance.CashSales := BalanceObj.Get('cash_sales', 0);
      AShiftStatus.Balance.CardSales := BalanceObj.Get('card_sales', 0);
      AShiftStatus.Balance.DiscountsSum := BalanceObj.Get('discounts_sum', 0);
      AShiftStatus.Balance.ExtraChargeSum := BalanceObj.Get('extra_charge_sum', 0);
      AShiftStatus.Balance.CashReturns := BalanceObj.Get('cash_returns', 0);
      AShiftStatus.Balance.CardReturns := BalanceObj.Get('card_returns', 0);
      AShiftStatus.Balance.ServiceIn := BalanceObj.Get('service_in', 0);
      AShiftStatus.Balance.ServiceOut := BalanceObj.Get('service_out', 0);
      // Для дати використовуємо спеціальну функцію парсингу
      AShiftStatus.Balance.UpdatedAt := ParseDateTime(BalanceObj.Get('updated_at', ''));
    end;
    // Якщо об'єкта "balance" немає, залишаються значення за замовчуванням (0 і 0 для дати)
    // ===== КІНЕЦЬ: НОВИЙ КОД ДЛЯ ПАРСИНГУ BALANCE =====

    // ===== - Універсальний парсинг signatures =====
    if (JsonData.Find('signatures') <> nil) and
       (JsonData.Items[JsonData.IndexOfName('signatures')].JSONType = jtArray) then
    begin
      SignaturesArray := JsonData.Arrays['signatures'];
      if Assigned(SignaturesArray) then
      begin
        SetLength(AShiftStatus.Signatures, SignaturesArray.Count);
        for I := 0 to SignaturesArray.Count - 1 do
        begin
          if SignaturesArray.Items[I].JSONType = jtObject then
          begin
            try
              // Використовуємо універсальну функцію для парсингу підпису
              AShiftStatus.Signatures[I] := ParseSignatureFromJSON(SignaturesArray.Objects[I]);
            except
              on E: Exception do
              begin
                Log('ParseShiftStatus: Помилка парсингу підпису ' + IntToStr(I) + ': ' + E.Message);
                AShiftStatus.Signatures[I] := TSignature.Create; // Створюємо пустий об'єкт
              end;
            end;
          end
          else
          begin
            // =====- Обробка null/неправильних значень =====
            Log('ParseShiftStatus: Елемент signatures[' + IntToStr(I) + '] не є об`єктом JSON');
            AShiftStatus.Signatures[I] := TSignature.Create; // Створюємо пустий об'єкт
          end;
        end;
      end;
    end
    else
    begin
      // Якщо signatures відсутній або не є масивом, створюємо пустий масив
      SetLength(AShiftStatus.Signatures, 0);
    end;
    Result := True;

  except
    on E: Exception do
    begin
      if Assigned(AShiftStatus) then
        FreeAndNil(AShiftStatus);
      Log('ParseShiftStatus: Помилка парсингу JSON: ' + E.Message);
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.BuildOpenShiftJsonData(const AShiftId, AFiscalCode, AFiscalDate: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    // Додаємо тільки ID зміни (якщо потрібно)
    if AShiftId = '' then
      Result.Add('id', GenerateUUID)
    else
      Result.Add('id', AShiftId);

    // ВИДАЛЯЄМО fiscal_code - сервер не потребує його
    // if AFiscalCode <> '' then
    //   Result.Add('fiscal_code', AFiscalCode);

    // ВИДАЛЯЄМО дублювання offline_mode
    Result.Add('offline_mode', True); // Тільки один раз

    // Додаємо дату (якщо потрібно)
    if AFiscalDate <> '' then
      Result.Add('fiscal_date', AFiscalDate);

  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;

function TReceiptWebAPI.BuildCloseShiftJsonData(ASkipClientNameCheck: Boolean; AReport: TShiftReport;
  const AFiscalCode, AFiscalDate: string): TJSONObject;
var
  ReportObj, PaymentObj, TaxObj: TJSONObject;
  PaymentsArray, TaxesArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('skip_client_name_check', ASkipClientNameCheck);

    if Assigned(AReport) then
    begin
      ReportObj := TJSONObject.Create;

      ReportObj.Add('id', AReport.Id);
      ReportObj.Add('serial', AReport.Serial);

      // Додаємо платежі
      if Length(AReport.Payments) > 0 then
      begin
        PaymentsArray := TJSONArray.Create;
        for I := 0 to High(AReport.Payments) do
        begin
          PaymentObj := TJSONObject.Create;
          PaymentObj.Add('type', AReport.Payments[I].PaymentType);
          PaymentObj.Add('provider_type', AReport.Payments[I].ProviderType);
          PaymentObj.Add('code', AReport.Payments[I].Code);
          PaymentObj.Add('label', AReport.Payments[I].LabelText);
          PaymentObj.Add('sell_sum', AReport.Payments[I].SellSum);
          PaymentObj.Add('return_sum', AReport.Payments[I].ReturnSum);
          PaymentObj.Add('service_in', AReport.Payments[I].ServiceIn);
          PaymentObj.Add('service_out', AReport.Payments[I].ServiceOut);
          PaymentObj.Add('cash_withdrawal', AReport.Payments[I].CashWithdrawal);
          PaymentObj.Add('cash_withdrawal_commission', AReport.Payments[I].CashWithdrawalCommission);
          PaymentsArray.Add(PaymentObj);
        end;
        ReportObj.Add('payments', PaymentsArray);
      end;

      // Додаємо податки
      if Length(AReport.Taxes) > 0 then
      begin
        TaxesArray := TJSONArray.Create;
        for I := 0 to High(AReport.Taxes) do
        begin
          TaxObj := TJSONObject.Create;
          TaxObj.Add('code', AReport.Taxes[I].Code);
          TaxObj.Add('label', AReport.Taxes[I].LabelText);
          TaxObj.Add('symbol', AReport.Taxes[I].Symbol);
          TaxObj.Add('rate', AReport.Taxes[I].Rate);
          TaxObj.Add('extra_rate', AReport.Taxes[I].ExtraRate);
          TaxObj.Add('sell_sum', AReport.Taxes[I].SellSum);
          TaxObj.Add('return_sum', AReport.Taxes[I].ReturnSum);
          TaxObj.Add('sales_turnover', AReport.Taxes[I].SalesTurnover);
          TaxObj.Add('returns_turnover', AReport.Taxes[I].ReturnsTurnover);
          TaxObj.Add('setup_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AReport.Taxes[I].SetupDate));
          TaxObj.Add('included', AReport.Taxes[I].Included);
          TaxObj.Add('no_vat', AReport.Taxes[I].NoVat);
          TaxesArray.Add(TaxObj);
        end;
        ReportObj.Add('taxes', TaxesArray);
      end;

      ReportObj.Add('sell_receipts_count', AReport.SellReceiptsCount);
      ReportObj.Add('return_receipts_count', AReport.ReturnReceiptsCount);
      ReportObj.Add('cash_withdrawal_receipts_count', AReport.CashWithdrawalReceiptsCount);
      ReportObj.Add('last_receipt_id', AReport.LastReceiptId);
      ReportObj.Add('initial', AReport.Initial);
      ReportObj.Add('balance', AReport.Balance);
      ReportObj.Add('sales_round_up', AReport.SalesRoundUp);
      ReportObj.Add('sales_round_down', AReport.SalesRoundDown);
      ReportObj.Add('returns_round_up', AReport.ReturnsRoundUp);
      ReportObj.Add('returns_round_down', AReport.ReturnsRoundDown);
      ReportObj.Add('created_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AReport.CreatedAt));

      Result.Add('report', ReportObj);
    end;

    if AFiscalCode <> '' then
      Result.Add('fiscal_code', AFiscalCode);

    if AFiscalDate <> '' then
      Result.Add('fiscal_date', AFiscalDate);

  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;




function TReceiptWebAPI.OpenShiftCurl(const AShiftId, AFiscalCode, AFiscalDate: string;
  out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
  CashRegisterStatus: TCashRegisterStatus;
  UseOfflineMode: Boolean;
  InitialBalance: Integer;
begin
  Log('OpenShiftCurl:---старт--------------------------------');
  // Ініціалізація змінних
  Result := False;
  AResponse := '';
  AShiftStatus := nil;
  UseOfflineMode := False;
  InitialBalance := 0; // Значення за замовчуванням
  JsonData := nil;
  StringList := TStringList.Create;
  CashRegisterStatus := nil;

  try
    // Перевірка, чи ініціалізовано ID каси
    if FCurrentCashRegisterId = '' then
    begin
      AResponse := 'ID каси не ініціалізовано. Спочатку викличте InitializeCashRegister або InitializeFirstCashRegister';
      Log(AResponse);
      Exit;
    end;

    // Перевірка дійсності токена
    if not IsTokenValid then
    begin
      // ЄДИНИЙ спосіб отримати новий токен - повторний логін
      Log('Токен недійсний, оновлюємо...');
      if not LoginCurl(FUsername, FPassword, AResponse) then
      begin
       AResponse := 'Token expired and refresh failed: ' + AResponse;
       Log('Помилка оновлення токена: ' + AResponse);
       Log('Потрібен повторний вхід: ' + AResponse);
       Exit;
      end;
      Log('Токен успішно оновлено');
    end
    else
    begin
      Log('Токен дійсний');
    end;

    // Перевірка режиму роботи каси - ОБОВ'ЯЗКОВО офлайн-режим
    Log('Перевірка режиму роботи каси...');
    if not GetCashRegisterStatusCurl(FCurrentCashRegisterId, AResponse, CashRegisterStatus) then
    begin
      Log('OpenShiftCurl: Не вдалося отримати статус каси: ' + AResponse);
      Exit;
    end;

    try
      if Assigned(CashRegisterStatus) then
      begin
        Log('Поточний режим каси - OfflineMode=' +
            BoolToStr(CashRegisterStatus.OfflineMode, True) +
            ', StayOffline=' + BoolToStr(CashRegisterStatus.StayOffline, True));

        // КРИТИЧНА ПЕРЕВІРКА: каса повинна бути в офлайн-режимі
        if not CashRegisterStatus.OfflineMode then
        begin
          AResponse := 'Неможливо відкрити зміну. Каса не знаходиться в офлайн-режимі. ' +
                       'Поточний режим: Online. Зміну можна відкривати тільки в офлайн-режимі.';
          Log(AResponse);
          Exit;
        end;

        // Додаткова перевірка: каса повинна бути налаштована на офлайн-роботу
        if not CashRegisterStatus.StayOffline then
        begin
          AResponse := 'Неможливо відкрити зміну. Каса не налаштована на постійну роботу в офлайн-режимі. ' +
                       'Параметр StayOffline = False. Зміну можна відкривати тільки при налаштуванні на офлайн-роботу.';
          Log(AResponse);
          Exit;
        end;

        // Якщо обидві умови виконані - використовуємо офлайн-режим
        UseOfflineMode := True;
        Log('Каса готова для роботи в офлайн-режимі - продовжуємо відкриття зміни');
      end
      else
      begin
        AResponse := 'Не вдалося отримати дані статусу каси';
        Log(AResponse);
        Exit;
      end;
    finally
      if Assigned(CashRegisterStatus) then
        FreeAndNil(CashRegisterStatus);
    end;

    // Підготовка JSON даних для відкриття зміни
    Log('Формування JSON даних для відкриття зміни...');
    JsonData := BuildOpenShiftJsonData(AShiftId, AFiscalCode, '');

    // Встановлюємо офлайн-режим явно
    JsonData.Add('offline_mode', UseOfflineMode);

    // Додаємо початковий баланс, якщо він відомий
    if InitialBalance > 0 then
      JsonData.Add('initial_balance', InitialBalance);

    JsonString := JsonData.AsJSON;

    // Логуємо JSON (обмежуємо логування через конфіденційність даних)
    Log('JSON дані: ' + Copy(JsonString, 1, 200) + '...');

    // Створення тимчасового файлу для JSON даних
    TempFile := GetTempDir + 'open_shift_' + GenerateUUID + '.json';
    Log('Тимчасовий файл: ' + TempFile);

    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // Формування curl команди з правильним URL та заголовками
      Command := Format('-X POST -H "accept: application/json" -H "X-Client-Name: %s" ' +
                       '-H "X-Client-Version: %s" -H "X-License-Key: %s" ' +
                       '-H "Authorization: Bearer %s" -H "Content-Type: application/json" ' +
                       '--data-binary "@%s" "%s/api/v1/shifts"',
        [FClientName, FClientVersion, FLicenseKey, FAuthInfo.Token, TempFile, FBaseURL]);

      //Log('OpenShiftCurl: Виконуємо команду: curl ' + Command);

      // Виконання curl команди
      Result := ExecuteCurlCommand(Command,'OpenShiftCurl','POST /api/v1/shifts', AResponse);

      // Детальне логування результату виконання
      Log('Результат виконання: ' + BoolToStr(Result, True));
      Log('Відповідь сервера: ' + Copy(AResponse, 1, 500));

      if Result then
      begin
        // Перевіряємо, чи відповідь містить помилки
        if CheckResponseForErrors(AResponse) then
        begin
          Log('Сервер повернув помилку: ' + AResponse);
          Result := False;
        end
        else
        begin
          Log('Парсинг відповіді сервера...');

          // ВИПРАВЛЕННЯ: Використовуємо ParseShiftStatus для коректного парсингу балансу
          Result := ParseShiftStatus(AResponse, AShiftStatus);

          if Result and Assigned(AShiftStatus) then
          begin
            Log('Успішно розпарсено статус зміни: ' + AShiftStatus.Status);

            // Обробка різних статусів зміни
            case AShiftStatus.Status of
              'OPENED':
                begin
                  Log('Зміна відкрита, оновлюємо дані...');

                  // ВИПРАВЛЕННЯ: Оновлюємо баланс з відповіді сервера
                  if Assigned(AShiftStatus.Balance) then
                  begin
                    FCurrentBalance := AShiftStatus.Balance.Balance;
                    Log('Баланс оновлено: ' +
                        Format('%.2f грн', [FCurrentBalance / 100]));
                  end
                  else
                  begin
                    Log('Інформація про баланс відсутня у відповіді');
                    FCurrentBalance := 0; // Резервне значення
                  end;

                  // Зберігаємо ID зміни для подальшого відстеження
                  FCurrentShiftId := AShiftStatus.Id;
                  SaveShiftToFile(FCurrentShiftId);
                  FLastBalanceUpdate := Now;

                  Log('Зміна успішно відкрита в офлайн-режимі');
                  Log(FormatBalanceInfo(AShiftStatus.Balance));
                end;

              'CREATED':
                begin
                  Log('Запит на відкриття офлайн-зміни успішний! Очікуємо підтвердження...');
                  // Зберігаємо ID зміни для подальшого відстеження
                  FCurrentShiftId := AShiftStatus.Id;
                  SaveShiftToFile(FCurrentShiftId);

                  // Запускаємо відстеження статусу з таймаутом 60 секунд
                  Log('Запуск відстеження статусу зміни...');
                  Result := WaitForShiftStatus(FCurrentShiftId, 'OPENED', AResponse, AShiftStatus, 60);

                  if Result and Assigned(AShiftStatus) then
                  begin
                    // ВИПРАВЛЕННЯ: Оновлюємо баланс після успішного відкриття
                    if Assigned(AShiftStatus.Balance) then
                    begin
                      FCurrentBalance := AShiftStatus.Balance.Balance;
                      Log('Баланс оновлено після очікування: ' +
                          Format('%.2f грн', [FCurrentBalance / 100]));
                    end;
                    Log('Зміна успішно відкрита в офлайн-режимі');
                  end
                  else
                    Log('Помилка відкриття зміни: ' + AResponse);
                end;

              'CLOSED', 'ERROR':
                begin
                  Log('Зміна в статусі ' + AShiftStatus.Status + ' - не можна відкрити');
                  Result := False;
                end;
            else
              Log('Невідомий статус зміни: ' + AShiftStatus.Status);
              Result := False;
            end;
          end
          else
          begin
            Log('Помилка парсингу відповіді сервера');
            if Assigned(AShiftStatus) then
              FreeAndNil(AShiftStatus);
          end;
        end;
      end
      else
      begin
        Log('Помилка виконання curl команди: ' + AResponse);
      end;
    finally
      // Очищення тимчасового файлу
      if FileExists(TempFile) then
      begin
        DeleteFile(TempFile);
        Log('Тимчасовий файл видалено');
      end;
    end;

  except
    on E: Exception do
    begin
      // Обробка винятків
      AResponse := 'CURL command error: ' + E.Message;
      Log('Виняток: ' + E.Message);
      Result := False;

      // Звільнення ресурсів у разі винятку
      if Assigned(AShiftStatus) then
        FreeAndNil(AShiftStatus);
    end;
  end;
end;



function TReceiptWebAPI.GetShiftStatusCurl(const AShiftId: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';
  AShiftStatus := nil;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    //Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/shifts/%s"',
      //[FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, AShiftId]);
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/shifts/%s"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, AShiftId]);

    Result := ExecuteCurlCommand(Command,'GetShiftStatusCurl','GET /api/v1/shifts/', AResponse);

    if Result then
    begin
      Result := ParseShiftStatus(AResponse, AShiftStatus);
      if not Result and Assigned(AShiftStatus) then
        FreeAndNil(AShiftStatus);
    end;
    if Result and Assigned(AShiftStatus) and Assigned(AShiftStatus.Balance) then
    begin
      Log(FormatBalanceInfo(AShiftStatus.Balance));
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.CloseShiftSimpleCurl(const AShiftId: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  Command, TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  AResponse := '';
  AShiftStatus := nil;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  StringList := TStringList.Create;
  try
    // Створюємо тимчасовий файл з правильним JSON
    TempFile := GetTempDir + 'close_shift_' + GenerateUUID + '.json';
    StringList.Text := '{}'; // Правильний JSON
    StringList.SaveToFile(TempFile);

    try
      // ВИПРАВЛЕНА команда - використовуємо --data-binary з файлом
      Command := Format('-X POST -H "accept: application/json" ' +
                       '-H "X-Client-Name: %s" -H "X-Client-Version: %s" ' +
                       '-H "Authorization: Bearer %s" -H "Content-Type: application/json" ' +
                       '--data-binary "@%s" "%s/api/v1/shifts/close"',
        [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL]);

      Result := ExecuteCurlCommand(Command,'CloseCurrentShiftCurl','POST /api/v1/shifts/close', AResponse);

      if Result then
      begin
        Result := ParseShiftStatus(AResponse, AShiftStatus);

        // ДОДАНО: Скидання балансу при закритті зміни
        if Result and Assigned(AShiftStatus) and (AShiftStatus.Status = 'CLOSED') then
        begin
          FCurrentBalance := 0;
          FLastBalanceUpdate := Now;
          FCurrentShiftId := '';
          Log('CloseShiftSimpleCurl: Зміну закрито, баланс скинуто до 0');
        end;
      end;

    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;




function TReceiptWebAPI.CloseShiftWithReportCurl(ASkipClientNameCheck: Boolean; AReport: TShiftReport;
  const AFiscalCode, AFiscalDate: string; out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  AResponse := '';
  AShiftStatus := nil;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  JsonData := nil;
  StringList := TStringList.Create;

  try
    JsonData := BuildCloseShiftJsonData(ASkipClientNameCheck, AReport, AFiscalCode, AFiscalDate);
    JsonString := JsonData.AsJSON;

    TempFile := GetTempDir + 'close_shift_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      Command := Format('-X POST -H "accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" -H "Content-Type: application/json" --data-binary "@%s" "%s/api/v1/shifts/close"',
        [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL]);

      Result := ExecuteCurlCommand(Command,'CloseShiftWithReportCurl','POST /api/v1/shifts/close', AResponse);

      if Result then
      begin
        Result := ParseShiftStatus(AResponse, AShiftStatus);

        // ДОДАНО: Скидання балансу при закритті зміни
        if Result and Assigned(AShiftStatus) and (AShiftStatus.Status = 'CLOSED') then
        begin
          FCurrentBalance := 0;
          FLastBalanceUpdate := Now;
          FCurrentShiftId := '';
          Log('CloseShiftWithReportCurl: Зміну закрито зі звітом, баланс скинуто до 0');
        end;
      end;
    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;




function TReceiptWebAPI.LoginCurl(AUsername, APassword: string; out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  FUsername := AUsername;
  FPassword := APassword;

  JsonData := nil;
  StringList := TStringList.Create;
  try
    // Формуємо JSON для авторизації
    JsonData := BuildAuthJsonData;
    JsonString := JsonData.AsJSON;

    Log('Login JSON: ' + JsonString);

    // Створюємо тимчасовий файл для JSON даних
    TempFile := GetTempDir + 'login_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // ВИПРАВЛЕНО: Видалено заголовок X-License-Key
      Command := Format('-X POST -H "Content-Type: application/json" -H "Accept: application/json" --data-binary "@%s" "%s/api/v1/cashier/signin"',
        [TempFile, FBaseURL]);

      // Виконуємо curl команду
      Result := ExecuteCurlCommand(Command,'LoginCurl','POST /api/v1/cashier/signin', AResponse);

      // Парсимо відповідь
      if Result then
        Result := ParseAuthResponse(AResponse)
      else
        Log('CURL command failed completely');

    finally
      // Видаляємо тимчасовий файл
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;
  finally
    JsonData.Free;
    StringList.Free;
  end;
end;


function TReceiptWebAPI.LogoutCurl(out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;

  // Перевіряємо, чи є токен
  if FAuthInfo.Token = '' then
  begin
    AResponse := 'No token available';
    Exit;
  end;

  try
    // Формуємо curl команду
    //Command := Format('-X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer %s" "%s/auth/logout"',
    //  [FAuthInfo.Token, FBaseURL]);
    Command := Format('-X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer %s" "%s/api/v1/cashier/signout"',
      [FAuthInfo.Token, FBaseURL]);
    // Виконуємо curl команду
    Result := ExecuteCurlCommand(Command,'LogoutCurl','POST /api/v1/cashier/signout', AResponse);

    // Очищаємо дані авторизації при успішному виході
    if Result then
    begin
      FAuthInfo.Token := '';
      FAuthInfo.ExpiresAt := 0;
      FAuthInfo.RefreshToken := '';
      //FAuthToken := '';
    end;
  except
    on E: Exception do
    begin
      AResponse := E.Message;
      Result := False;
    end;
  end;
end;

// Додайте в private секцію TReceiptWebAPI
function TReceiptWebAPI.BoolToStr(Value: Boolean; UseBoolStrs: Boolean = False): string;
begin
  if UseBoolStrs then
  begin
    if Value then
      Result := 'True'
    else
      Result := 'False';
  end
  else
  begin
    if Value then
      Result := '1'
    else
      Result := '0';
  end;
end;

// Додайте цю функцію для перевірки HTTP статусу з JSON відповіді
function TReceiptWebAPI.CheckResponseForErrors(const AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
begin
  Result := False; // Не містить помилок
  try
    JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
    try
      JsonData := JsonParser.Parse as TJSONObject;

      // Перевіряємо common error fields
      if (JsonData.Get('error', '') <> '') or (JsonData.Get('message', '') <> '') or
         (JsonData.Get('detail', '') <> '') or (JsonData.Get('validation_error', '') <> '') then
      begin
        Result := True; // Містить помилки
      end;
    finally
      JsonData.Free;
    end;
  except
    // Якщо не JSON або помилка парсингу - не вважаємо за помилку
    Result := False;
  end;
end;


function TReceiptWebAPI.WaitForShiftStatus(const AShiftId: string;
  const ATargetStatus: string; out AResponse: string;
  out AShiftStatus: TShiftStatus; ATimeoutSec: Integer = 60): Boolean;
var
  StartTime: TDateTime;
  ElapsedSeconds: Integer;
  StatusCheckCount: Integer;
begin
  Result := False;
  AShiftStatus := nil;
  StartTime := Now;
  StatusCheckCount := 0;

  Log('Очікування статусу ' + ATargetStatus + ' для зміни ' + AShiftId);
  Log('Таймаут: ' + IntToStr(ATimeoutSec) + ' секунд');

  while SecondsBetween(Now, StartTime) < ATimeoutSec do
  begin
    Inc(StatusCheckCount);
    Log('Перевірка статусу #' + IntToStr(StatusCheckCount));

    // Перевіряємо статус зміни
    if not GetShiftStatusCurl(AShiftId, AResponse, AShiftStatus) then
    begin
      Log('Помилка перевірки статусу зміни: ' + AResponse);
      Sleep(3000); // Зачекати перед наступною спробою
      Continue;
    end;

    if Assigned(AShiftStatus) then
    begin
      Log('Поточний статус: ' + AShiftStatus.Status);

      if AShiftStatus.Status = ATargetStatus then
      begin
        Result := True;
        Log('Досягнуто цільовий статус: ' + ATargetStatus);
        Exit;
      end
      else if (AShiftStatus.Status = 'ERROR') or (AShiftStatus.Status = 'CLOSED') then
      begin
        Log('Помилка: зміна в статусі ' + AShiftStatus.Status);
        Result := False;
        Exit;
      end;

      FreeAndNil(AShiftStatus);
    end;

    // Зачекати перед наступною перевіркою
    Sleep(3000); // 3 секунди
    ElapsedSeconds := SecondsBetween(Now, StartTime);
    Log('Очікування... (' + IntToStr(ElapsedSeconds) + 'с/' +
        IntToStr(ATimeoutSec) + 'с)');
  end;

  Log('Час очікування статусу вийшов');
  AResponse := 'Таймаут очікування статусу зміни';
end;


function TReceiptWebAPI.CheckCurrentShift(out AResponse: string;
  out AShiftStatus: TShiftStatus): Boolean;
begin
  Result := False;
  AShiftStatus := nil;

  if FCurrentShiftId = '' then
  begin
    AResponse := 'Немає збереженого ID зміни';
    Exit;
  end;

  Log('Перевірка поточної зміни: ' + FCurrentShiftId);
  Result := GetShiftStatusCurl(FCurrentShiftId, AResponse, AShiftStatus);
end;



function TReceiptWebAPI.GetCurrentShiftIdCurl(out AResponse: string): string;
var
  Command: string;
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
  ShiftsArray: TJSONArray;
begin
  Result := '';

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    Command := Format('-X GET -H "Accept: application/json" -H "Authorization: Bearer %s" "%s/api/v1/shifts?status=OPENED"',
      [FAuthInfo.Token, FBaseURL]);

    if ExecuteCurlCommand(Command, 'GetCurrentShiftIdCurl', 'GET /api/v1/shifts?status=OPENED', AResponse) then
    begin
      JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
      try
        JsonData := JsonParser.Parse as TJSONObject;

        // Спроба отримати масив results
        if JsonData.Find('results') <> nil then
          ShiftsArray := JsonData.Arrays['results']
        else
          ShiftsArray := nil;

        if (ShiftsArray <> nil) and (ShiftsArray.Count > 0) then
        begin
          Result := ShiftsArray.Objects[0].Get('id', '');
          Log('Знайдено відкриту зміну: ' + Result);
        end
        else
        begin
          Log('Не знайдено відкритих змін');
        end;
      finally
        JsonData.Free;
      end;
    end
    else
    begin
      Log('Помилка отримання поточної зміни: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetCurrentShiftIdCurl: Виняток: ' + E.Message);
    end;
  end;
end;

function TReceiptWebAPI.OpenShiftWithRecovery(const AShiftId, AFiscalCode, AFiscalDate: string;
  out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
begin
  // Спроба знайти вже відкриту зміну
  CurrentShiftId := GetCurrentShiftIdCurl(AResponse);

  if CurrentShiftId <> '' then
  begin
    // Використовуємо знайдену зміну
    FCurrentShiftId := CurrentShiftId;
    Result := GetShiftStatusCurl(CurrentShiftId, AResponse, AShiftStatus);
    if Result then
      Log('Відновлено існуючу зміну: ' + CurrentShiftId);
  end
  else
  begin
    // Створюємо нову зміну
    Result := OpenShiftCurl(AShiftId, AFiscalCode, AFiscalDate, AResponse, AShiftStatus);
  end;
end;


procedure TReceiptWebAPI.SaveShiftIdToFile;
var
  IniFile: TIniFile;
  ConfigDir: string;
begin
  ConfigDir := GetAppConfigDir(False);
  ForceDirectories(ConfigDir); // Создаем директорию, если не существует
  IniFile := TIniFile.Create(ConfigDir + 'shift.ini');
  try
    IniFile.WriteString('Shift', 'ID', FCurrentShiftId);
    IniFile.WriteDateTime('Shift', 'LastUpdate', Now);
  finally
    IniFile.Free;
  end;
end;

procedure TReceiptWebAPI.LoadShiftIdFromFile;
var
  IniFile: TIniFile;
  ConfigDir: string;
begin
  ConfigDir := GetAppConfigDir(False);
  if not DirectoryExists(ConfigDir) then
    Exit;

  IniFile := TIniFile.Create(ConfigDir + 'shift.ini');
  try
    FCurrentShiftId := IniFile.ReadString('Shift', 'ID', '');
    // Перевіряємо чи зміна ще актуальна (не старіша за 24 години)
    if (FCurrentShiftId <> '') and
       (HoursBetween(Now, IniFile.ReadDateTime('Shift', 'LastUpdate', 0)) < 24) then
    begin
      Log('Завантажено збережену зміну: ' + FCurrentShiftId);
    end
    else
    begin
      FCurrentShiftId := '';
    end;
  finally
    IniFile.Free;
  end;
end;



function TReceiptWebAPI.ForceCloseShift(out AResponse: string): Boolean;
var
  ShiftStatus: TShiftStatus;
begin
  // Знаходимо поточну зміну
  FCurrentShiftId := GetCurrentShiftIdCurl(AResponse);

  if FCurrentShiftId <> '' then
  begin
    Log('Примусове закриття зміни: ' + FCurrentShiftId);
    Result := CloseShiftSimpleCurl(FCurrentShiftId, AResponse, ShiftStatus);

    // ДОДАНО: Скидання балансу навіть якщо закриття не вдалося
    if Result then
    begin
      FCurrentBalance := 0;
      FLastBalanceUpdate := Now;
      FCurrentShiftId := '';
      Log('ForceCloseShift: Зміну примусово закрито, баланс скинуто до 0');
    end
    else
    begin
      // Навіть якщо закриття не вдалося, скидаємо внутрішній стан
      FCurrentBalance := 0;
      FLastBalanceUpdate := Now;
      FCurrentShiftId := '';
      Log('ForceCloseShift: Не вдалося закрити зміну, але внутрішній стан скинуто');
    end;
  end
  else
  begin
    Result := True; // Немає відкритих змін
    AResponse := 'Немає відкритих змін для закриття';

    // ДОДАНО: Переконуємося, що баланс скинутий
    FCurrentBalance := 0;
    FLastBalanceUpdate := Now;
  end;
end;

function TReceiptWebAPI.GetReceiptStatusCurl(const AReceiptId: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
var
  Command: string;
begin
  Result := False;
  AReceiptResponse := nil;

  if AReceiptId = '' then
  begin
    Log('Помилка: пустий ReceiptId');
    Exit(False);
  end;

  if not IsValidUUID(AReceiptId) then
  begin
    Log('Помилка: невірний формат ReceiptId: ' + AReceiptId);
    Exit(False);
  end;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    //Command := Format('-X GET -H "Accept: application/json" -H "Authorization: Bearer %s" "%s/receipts/%s"',
    //  [FAuthInfo.Token, FBaseURL, AReceiptId]);
    Command := Format('-X GET -H "Accept: application/json" -H "Authorization: Bearer %s" "%s/api/v1/receipts/%s"',
      [FAuthInfo.Token, FBaseURL, AReceiptId]);
    Result := ExecuteCurlCommand(Command,'GetReceiptStatusCurl','GET /receipts/ReceiptID', AResponse);

    if Result then
    begin
      AReceiptResponse := TReceiptResponse.Create;
      Result := AReceiptResponse.ParseFromJSON(AResponse, Self);
      if not Result then
        FreeAndNil(AReceiptResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;




function TReceiptWebAPI.CheckConnectivityCurl(out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';

  // Перевіряємо чи токен дійсний, якщо ні - оновлюємо
  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    // ВИПРАВЛЕНА команда - використовуємо правильний ендпоінт
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/cashier/me"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL]);

    Log('CheckConnectivityCurl: Виконуємо команду: curl ' + Command);

    // Виконуємо curl команду
    Result := ExecuteCurlCommand(Command,'CheckConnectivityCurl','GET /api/v1/cashier/me', AResponse);

    if Result then
    begin
      // Перевіряємо, чи відповідь містить дані касира
      Result := (Pos('"id":"', AResponse) > 0) or
                (Pos('"cashier"', AResponse) > 0) or
                (Pos('"full_name"', AResponse) > 0);

      if not Result then
      begin
        Log('CheckConnectivityCurl: Відповідь не містить даних касира: ' + Copy(AResponse, 1, 200));
      end
      else
      begin
        Log('CheckConnectivityCurl: Зʼєднання успішне, касир автентифікований');
      end;
    end
    else
    begin
      Log('CheckConnectivityCurl: Помилка виконання curl команди: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('CheckConnectivityCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.GetFiscalMemoryStatusCurl(out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';

  // Перевіряємо чи токен дійсний, якщо ні - оновлюємо
  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    // Формуємо curl команду для отримання статусу фіскальної пам'яті
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/status/fiscal-memory"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL]);

    Log('GetFiscalMemoryStatusCurl: Виконуємо команду: curl ' + Command);

    // Виконуємо curl команду
    Result := ExecuteCurlCommand(Command,'GetFiscalMemoryStatusCurl','GET /api/v1/status/fiscal-memory', AResponse);

    if Result then
    begin
      // Перевіряємо, чи відповідь містить дані про фіскальну пам'ять
      Result := (Pos('"fiscal_memory"', AResponse) > 0) or
                (Pos('"free_space"', AResponse) > 0) or
                (Pos('"total_space"', AResponse) > 0);

      if not Result then
      begin
        Log('GetFiscalMemoryStatusCurl: Відповідь не містить даних фіскальної пам''яті: ' + Copy(AResponse, 1, 200));
      end;
    end
    else
    begin
      Log('GetFiscalMemoryStatusCurl: Помилка виконання curl команди: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetFiscalMemoryStatusCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.GetPrinterStatusCurl(out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';

  // Перевіряємо чи токен дійсний, якщо ні - оновлюємо
  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    // Формуємо curl команду для отримання статусу принтера
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/status/printer"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL]);

    Log('GetPrinterStatusCurl: Виконуємо команду: curl ' + Command);

    // Виконуємо curl команду
    Result := ExecuteCurlCommand(Command,'GetPrinterStatusCurl','GET /api/v1/status/printer', AResponse);

    if Result then
    begin
      // Перевіряємо, чи відповідь містить дані про принтер
      Result := (Pos('"printer"', AResponse) > 0) or
                (Pos('"status"', AResponse) > 0) or
                (Pos('"paper_status"', AResponse) > 0) or
                (Pos('"online"', AResponse) > 0);

      if not Result then
      begin
        Log('GetPrinterStatusCurl: Відповідь не містить даних про принтер: ' + Copy(AResponse, 1, 200));
      end;
    end
    else
    begin
      Log('GetPrinterStatusCurl: Помилка виконання curl команди: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetPrinterStatusCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.SaveOfflineReceipt(AReceipt: TReceipt): Boolean;
var
  IniFile: TIniFile;
  ConfigDir, ReceiptsDir, ReceiptFile: string;
  StringList: TStringList;
  JsonData: TJSONObject;
  I: Integer;
begin
  Result := False;

  // Перевіряємо вхідні параметри
  if not Assigned(AReceipt) then
  begin
    Log('SaveOfflineReceipt: Помилка - переданий нульовий об''єкт чека');
    Exit;
  end;

  // Створюємо директорії для зберігання офлайн-чеків
  ConfigDir := GetAppConfigDir(False);
  ReceiptsDir := ConfigDir + 'offline_receipts' + PathDelim;
  ForceDirectories(ReceiptsDir);

  try
    // Генеруємо унікальне ім'я файлу для чека
    if AReceipt.Id = '' then
      AReceipt.Id := GenerateUUID;

    ReceiptFile := ReceiptsDir + AReceipt.Id + '.json';

    // Створюємо JSON з даними чека
    JsonData := BuildJsonData(AReceipt);
    try
      StringList := TStringList.Create;
      try
        StringList.Text := JsonData.AsJSON;

        // Зберігаємо чек у файл
        StringList.SaveToFile(ReceiptFile);

        // Оновлюємо індекс офлайн-чеків
        IniFile := TIniFile.Create(ConfigDir + 'offline_queue.ini');
        try
          IniFile.WriteString('Queue', AReceipt.Id, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
          IniFile.WriteInteger('Settings', 'TotalOfflineReceipts', GetOfflineQueueStatus + 1);
        finally
          IniFile.Free;
        end;

        Log('SaveOfflineReceipt: Чек збережено в офлайн-черзі: ' + AReceipt.Id);
        Result := True;
      finally
        StringList.Free;
      end;
    finally
      JsonData.Free;
    end;

  except
    on E: Exception do
    begin
      Log('SaveOfflineReceipt: Помилка збереження офлайн-чека: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TReceiptWebAPI.ProcessOfflineReceipts: Boolean;
var
  IniFile: TIniFile;
  ConfigDir, ReceiptsDir: string;
  StringList: TStringList;
  Sections: TStringList;
  I: Integer;
  ReceiptId, ReceiptFile, Response: string;
  Receipt: TReceipt;
  ReceiptResponse: TReceiptResponse;
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
begin
  Result := True;
  ConfigDir := GetAppConfigDir(False);
  ReceiptsDir := ConfigDir + 'offline_receipts' + PathDelim;

  // Перевіряємо чи існує директорія з офлайн-чеками
  if not DirectoryExists(ReceiptsDir) then
  begin
    Log('ProcessOfflineReceipts: Директорія офлайн-чеків не існує');
    Exit(True);
  end;

  // Завантажуємо список чеків з черги
  IniFile := TIniFile.Create(ConfigDir + 'offline_queue.ini');
  Sections := TStringList.Create;
  try
    IniFile.ReadSection('Queue', Sections);

    Log('ProcessOfflineReceipts: Знайдено ' + IntToStr(Sections.Count) + ' чеків в черзі');

    // Обробляємо кожен чек по черзі
    for I := 0 to Sections.Count - 1 do
    begin
      ReceiptId := Sections[I];
      ReceiptFile := ReceiptsDir + ReceiptId + '.json';

      if FileExists(ReceiptFile) then
      begin
        try
          // Завантажуємо чек з файлу
          StringList := TStringList.Create;
          try
            StringList.LoadFromFile(ReceiptFile);

            // Парсимо JSON - ИСПРАВЛЕННАЯ СТРОКА
            JsonParser := TJSONParser.Create(StringList.Text, [joUTF8]);
            try
              JsonData := JsonParser.Parse as TJSONObject;
              try
                // Створюємо об'єкт чека
                Receipt := TReceipt.Create;
                try
                  // Заповнюємо дані чека (спрощена версія)
                  Receipt.Id := JsonData.Get('id', '');
                  Receipt.CashierName := JsonData.Get('cashier_name', '');
                  // ... заповнюємо інші поля

                  // Відправляємо чек на сервер
                  if SendReceiptCurl(Receipt, Response, ReceiptResponse) then
                  begin
                    // Успішно відправлено - видаляємо з черги
                    DeleteFile(ReceiptFile);
                    IniFile.DeleteKey('Queue', ReceiptId);
                    Log('ProcessOfflineReceipts: Чек ' + ReceiptId + ' успішно відправлено');
                  end
                  else
                  begin
                    // Помилка відправки - залишаємо в черзі
                    Log('ProcessOfflineReceipts: Помилка відправки чека ' + ReceiptId + ': ' + Response);
                    Result := False; // Хоча б один чек не вдалося відправити
                  end;

                finally
                  if Assigned(ReceiptResponse) then
                    FreeAndNil(ReceiptResponse);
                  Receipt.Free;
                end;

              finally
                JsonData.Free;
              end;
            finally
              JsonParser.Free;
            end;
          finally
            StringList.Free;
          end;

        except
          on E: Exception do
          begin
            Log('ProcessOfflineReceipts: Помилка обробки чека ' + ReceiptId + ': ' + E.Message);
            Result := False;
          end;
        end;
      end
      else
      begin
        // Файл не існує - видаляємо з черги
        IniFile.DeleteKey('Queue', ReceiptId);
        Log('ProcessOfflineReceipts: Файл чека ' + ReceiptId + ' не знайдено, видалено з черги');
      end;
    end;

    // Оновлюємо загальну кількість чеків у черзі
    IniFile.WriteInteger('Settings', 'TotalOfflineReceipts', Sections.Count);

  finally
    Sections.Free;
    IniFile.Free;
  end;
end;

function TReceiptWebAPI.GetOfflineQueueStatus: Integer;
var
  IniFile: TIniFile;
  ConfigDir, ReceiptsDir: string;
  Sections: TStringList;
  FileCount: Integer;
  SearchRec: TSearchRec;
begin
  ConfigDir := GetAppConfigDir(False);
  ReceiptsDir := ConfigDir + 'offline_receipts' + PathDelim;

  // Перевіряємо чи існує директорія
  if not DirectoryExists(ReceiptsDir) then
  begin
    Result := 0;
    Exit;
  end;

  // Рахуємо кількість файлів у директорії
  FileCount := 0;
  if FindFirst(ReceiptsDir + '*.json', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        Inc(FileCount);
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  // Оновлюємо значення в ini-файлі
  IniFile := TIniFile.Create(ConfigDir + 'offline_queue.ini');
  try
    // Отримуємо кількість з ini-файлу або з кількості файлів
    Result := IniFile.ReadInteger('Settings', 'TotalOfflineReceipts', FileCount);

    // Якщо значення не співпадає, оновлюємо
    if Result <> FileCount then
    begin
      Result := FileCount;
      IniFile.WriteInteger('Settings', 'TotalOfflineReceipts', FileCount);
    end;
  finally
    IniFile.Free;
  end;

  Log('GetOfflineQueueStatus: В офлайн-черзі знаходиться ' + IntToStr(Result) + ' чеків');
end;

function TReceiptWebAPI.PaymentProviderToString(AProvider: TPaymentProvider): string;
begin
  case AProvider of
    ppBank: Result := 'BANK';
    ppTapXPhone: Result := 'TAPXPHONE';
    ppPosControl: Result := 'POSCONTROL';
    ppTerminal: Result := 'TERMINAL';
  else
    Result := 'BANK';
  end;
end;

function TReceiptWebAPI.CreateServiceOperation(AOperationType: string; AAmount: Integer; ADescription: string): TServiceOperation;
begin
  Result := TServiceOperation.Create;
  Result.OperationType := AOperationType;
  Result.Amount := AAmount;
  Result.Description := ADescription;
end;

function TReceiptWebAPI.CreateSignature(ASignatureType, AValue: string): TSignature;
begin
  Result := TSignature.Create;
  Result.SignatureType := ASignatureType;
  Result.Value := AValue;
end;



function TReceiptWebAPI.CancelReceiptCurl(const AReceiptId, AReason: string; out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
begin
  Result := False;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  JsonData := TJSONObject.Create;
  StringList := TStringList.Create;
  try
    JsonData.Add('reason', AReason);
    JsonString := JsonData.AsJSON;

    TempFile := GetTempDir + 'cancel_receipt_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      Command := Format('-X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer %s" --data-binary "@%s" "%s/receipts/%s/cancel"',
        [FAuthInfo.Token, TempFile, FBaseURL, AReceiptId]);

      Result := ExecuteCurlCommand(Command,'CancelReceiptCurl','POST /receipts/ReceiptID/cancel', AResponse);
    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;
  finally
    JsonData.Free;
    StringList.Free;
  end;
end;

function TReceiptWebAPI.ParseShiftReport(const JSONString: string; out AShiftReport: TShiftReport): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  PaymentsArray, TaxesArray: TJSONArray;
  I: Integer;
  PaymentObj, TaxObj: TJSONObject;
begin
  Result := False;
  AShiftReport := nil;

  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);
  try
    JsonData := JsonParser.Parse as TJSONObject;

    AShiftReport := TShiftReport.Create;
    try
      // Основні поля звіту
      AShiftReport.Id := JsonData.Get('id', '');
      AShiftReport.Serial := JsonData.Get('serial', 0);
      AShiftReport.SellReceiptsCount := JsonData.Get('sell_receipts_count', 0);
      AShiftReport.ReturnReceiptsCount := JsonData.Get('return_receipts_count', 0);
      AShiftReport.CashWithdrawalReceiptsCount := JsonData.Get('cash_withdrawal_receipts_count', 0);
      AShiftReport.LastReceiptId := JsonData.Get('last_receipt_id', '');
      AShiftReport.Initial := JsonData.Get('initial', 0);
      AShiftReport.Balance := JsonData.Get('balance', 0);
      AShiftReport.SalesRoundUp := JsonData.Get('sales_round_up', 0);
      AShiftReport.SalesRoundDown := JsonData.Get('sales_round_down', 0);
      AShiftReport.ReturnsRoundUp := JsonData.Get('returns_round_up', 0);
      AShiftReport.ReturnsRoundDown := JsonData.Get('returns_round_down', 0);
      AShiftReport.CreatedAt := ParseDateTime(JsonData.Get('created_at', ''));
      AShiftReport.DiscountsSum := JsonData.Get('discounts_sum', 0);
      AShiftReport.ExtraChargeSum := JsonData.Get('extra_charge_sum', 0);

      // Парсимо платежі
      if (JsonData.Find('payments') <> nil) and
         (JsonData.Items[JsonData.IndexOfName('payments')].JSONType = jtArray) then
      begin
        PaymentsArray := JsonData.Arrays['payments'];
        if Assigned(PaymentsArray) then
        begin
          SetLength(AShiftReport.Payments, PaymentsArray.Count);
          for I := 0 to PaymentsArray.Count - 1 do
          begin
            if PaymentsArray.Items[I].JSONType = jtObject then
            begin
              PaymentObj := PaymentsArray.Objects[I];
              AShiftReport.Payments[I] := TShiftPayment.Create;

              AShiftReport.Payments[I].PaymentType := PaymentObj.Get('type', '');
              AShiftReport.Payments[I].ProviderType := PaymentObj.Get('provider_type', '');
              AShiftReport.Payments[I].Code := PaymentObj.Get('code', 0);
              AShiftReport.Payments[I].LabelText := PaymentObj.Get('label', '');
              AShiftReport.Payments[I].SellSum := PaymentObj.Get('sell_sum', 0);
              AShiftReport.Payments[I].ReturnSum := PaymentObj.Get('return_sum', 0);
              AShiftReport.Payments[I].ServiceIn := PaymentObj.Get('service_in', 0);
              AShiftReport.Payments[I].ServiceOut := PaymentObj.Get('service_out', 0);
              AShiftReport.Payments[I].CashWithdrawal := PaymentObj.Get('cash_withdrawal', 0);
              AShiftReport.Payments[I].CashWithdrawalCommission := PaymentObj.Get('cash_withdrawal_commission', 0);
            end;
          end;
        end;
      end;

      // Парсимо податки
      if (JsonData.Find('taxes') <> nil) and
         (JsonData.Items[JsonData.IndexOfName('taxes')].JSONType = jtArray) then
      begin
        TaxesArray := JsonData.Arrays['taxes'];
        if Assigned(TaxesArray) then
        begin
          SetLength(AShiftReport.Taxes, TaxesArray.Count);
          for I := 0 to TaxesArray.Count - 1 do
          begin
            if TaxesArray.Items[I].JSONType = jtObject then
            begin
              TaxObj := TaxesArray.Objects[I];
              AShiftReport.Taxes[I] := TShiftTax.Create;

              AShiftReport.Taxes[I].Id := TaxObj.Get('id', '');
              AShiftReport.Taxes[I].Code := TaxObj.Get('code', 0);
              AShiftReport.Taxes[I].LabelText := TaxObj.Get('label', '');
              AShiftReport.Taxes[I].Symbol := TaxObj.Get('symbol', '');
              AShiftReport.Taxes[I].Rate := TaxObj.Get('rate', 0.0);
              AShiftReport.Taxes[I].SellSum := TaxObj.Get('sell_sum', 0);
              AShiftReport.Taxes[I].ReturnSum := TaxObj.Get('return_sum', 0);
              AShiftReport.Taxes[I].SalesTurnover := TaxObj.Get('sales_turnover', 0);
              AShiftReport.Taxes[I].ReturnsTurnover := TaxObj.Get('returns_turnover', 0);
              AShiftReport.Taxes[I].NoVat := TaxObj.Get('no_vat', False);
              AShiftReport.Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');
              AShiftReport.Taxes[I].SetupDate := ParseDateTime(TaxObj.Get('setup_date', ''));
            end;
          end;
        end;
      end;

      Result := True;

    except
      on E: Exception do
      begin
        FreeAndNil(AShiftReport);
        Log('ParseShiftReport: Помилка парсингу звіту: ' + E.Message);
        Result := False;
      end;
    end;

  except
    on E: Exception do
    begin
      Log('ParseShiftReport: Помилка парсингу JSON: ' + E.Message);
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.ParseAPIError(const JSONString: string; out AError: TAPIError): Boolean;
begin
  // TODO: Implement ParseAPIError
  Result := False;
  AError := nil;
end;



function TReceiptWebAPI.GetShiftReportCurl(const AShiftId: string; out AResponse: string; out AShiftReport: TShiftReport): Boolean;
begin
  // TODO: Implement GetShiftReportCurl
  Result := False;
  AShiftReport := nil;
end;


function TReceiptWebAPI.GetCashierInfoCurl(out AResponse: string; out ACashier: TCashier): Boolean;
begin
  // TODO: Implement GetCashierInfoCurl
  Result := False;
  ACashier := nil;
end;


function TReceiptWebAPI.GetCashRegistersListCurl(out AResponse: string; out ACashRegisters: TCashRegisterArray): Boolean;
var
  i: Integer;
  JsonParser: TJSONParser;
  JsonRoot: TJSONObject;
  JsonData: TJSONArray;
  JsonObj: TJSONObject;
  ErrorMsg: string;
  DetailArray: TJSONArray;
  Command: string;
begin
  Result := False;
  AResponse := '';

  // Перевірка стану токену
  if not IsTokenValid then
  begin
    AResponse := 'API не ініціалізоване або токен недійсний';
    Log('Помилка: ' + AResponse);
    Exit;
  end;

  // Кешування списку кас
  if (FLastCashRegisterUpdate > 0) and
     ((Now - FLastCashRegisterUpdate) < 5 * OneMinute) then
  begin
    Log('Використовуємо кешований список кас');
    AResponse := FLastCashRegisterResponse;
    Result := True;
    Exit;
  end;

  // Формування команди curl
  Command := '-H "Authorization: Bearer ' + FAuthInfo.Token + '" https://api.checkbox.ua/api/v1/cash-registers';

  // Виконання запиту через ExecuteCurlCommand
  Result := ExecuteCurlCommand(Command, 'GetCashRegistersListCurl', '/api/v1/cash-registers', AResponse);
  if not Result then
  begin
    Log('Помилка отримання списку кас: ' + AResponse);
    Exit;
  end;

  // Парсинг JSON
  JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
  try
    JsonRoot := JsonParser.Parse as TJSONObject;
    try
      // Перевірка на помилку (наприклад, 422)
      if JsonRoot.Find('detail') <> nil then
      begin
        ErrorMsg := JsonRoot.Get('message', 'Unknown error');
        DetailArray := JsonRoot.Get('detail', TJSONArray(nil));
        if Assigned(DetailArray) then
        begin
          for i := 0 to DetailArray.Count - 1 do
          begin
            ErrorMsg := ErrorMsg + '; ' + DetailArray.Objects[i].Get('msg', '');
          end;
        end;
        AResponse := ErrorMsg;
        Log('Помилка сервера: ' + ErrorMsg);
        Result := False;
        Exit;
      end;

      // Обробка успішної відповіді
      if JsonRoot.Find('results') <> nil then
      begin
        JsonData := JsonRoot.Get('results', TJSONArray(nil));
        if Assigned(JsonData) then
        begin
          // Заповнення масиву ACashRegisters
          SetLength(ACashRegisters, JsonData.Count);
          for i := 0 to JsonData.Count - 1 do
          begin
            try
              if JsonData.Items[i].JSONType = jtObject then
              begin
                JsonObj := JsonData.Objects[i];
                ACashRegisters[i] := TCashRegister.Create;
                ACashRegisters[i].Id := JsonObj.Get('id', '');
                ACashRegisters[i].FiscalNumber := JsonObj.Get('fiscal_number', '');
                ACashRegisters[i].Active := JsonObj.Get('active', False);
                ACashRegisters[i].Number := JsonObj.Get('number', '');
                ACashRegisters[i].IsTest := JsonObj.Get('is_test', False);
              end
              else
              begin
                Log('Елемент #' + IntToStr(i) + ' не є об''єктом');
                ACashRegisters[i] := nil;
              end;
            except
              on E: Exception do
              begin
                Log('Помилка парсингу каси #' + IntToStr(i) + ': ' + E.Message +
                    ' (JSON: ' + IfThen(Assigned(JsonObj), JsonObj.AsJSON, 'null'));
                if Assigned(ACashRegisters[i]) then
                  FreeAndNil(ACashRegisters[i]);
                ACashRegisters[i] := nil;
              end;
            end;
          end;
          Log('Отримано список кас: ' + IntToStr(Length(ACashRegisters)) + ' шт.');
          // Збереження відповіді для кешування
          FLastCashRegisterResponse := AResponse;
          FLastCashRegisterUpdate := Now;
        end
        else
        begin
          Log('Поле "results" не є масивом');
          AResponse := 'Invalid JSON: results is not an array';
          Result := False;
        end;
      end
      else
      begin
        Log('Поле "results" не знайдено в JSON');
        AResponse := 'Invalid JSON: results field missing';
        Result := False;
      end;
    finally
      JsonRoot.Free;
    end;
  finally
    JsonParser.Free;
  end;
end;


function TReceiptWebAPI.FindCashRegisterByFiscalNumber(const AFiscalNumber: string;
  out ACashRegisterId: string; out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  CashRegistersArray: TJSONArray;
  I: Integer;
  CashRegisterObj: TJSONObject;
  SomeArrayVar: TCashRegisterArray;
begin
  Result := False;
  ACashRegisterId := '';

  // Отримуємо список всіх кас
  if not GetCashRegistersListCurl(AResponse,SomeArrayVar) then
    Exit;

  try
    JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
    JsonData := JsonParser.Parse as TJSONObject;

    // Перевіряємо структуру відповіді
    if JsonData.Find('results') <> nil then
      CashRegistersArray := JsonData.Arrays['results']
    else if JsonData.Find('cash_registers') <> nil then
      CashRegistersArray := JsonData.Arrays['cash_registers']
    else
      CashRegistersArray := nil;

    if Assigned(CashRegistersArray) then
    begin
      for I := 0 to CashRegistersArray.Count - 1 do
      begin
        CashRegisterObj := CashRegistersArray.Objects[I];
        if CashRegisterObj.Get('fiscal_number', '') = AFiscalNumber then
        begin
          ACashRegisterId := CashRegisterObj.Get('id', '');
          Result := True;
          Break;
        end;
      end;
    end;

  except
    on E: Exception do
    begin
      AResponse := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;





function TReceiptWebAPI.RecoverShift(out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  ShiftId: string;
begin
  Result := False;
  AShiftStatus := nil;

  // Спроба завантажити збережену зміну
  ShiftId := LoadShiftFromFile;
  if ShiftId = '' then
  begin
    AResponse := 'Немає збереженої зміни для відновлення';
    Exit;
  end;

  Log('Спроба відновлення зміни: ' + ShiftId);

  // Перевірити статус збереженої зміни
  Result := GetShiftStatusCurl(ShiftId, AResponse, AShiftStatus);

  if Result and Assigned(AShiftStatus) then
  begin
    if AShiftStatus.Status = 'OPENED' then
    begin
      FCurrentShiftId := ShiftId;

      // ДОДАНО: Відновлення балансу при відновленні зміни
      FLastBalanceUpdate := 0; // Примусове оновлення балансу
      GetCurrentBalance(AResponse);

      Log('Зміну успішно відновлено: ' + ShiftId);
    end
    else
    begin
      Log('Збережена зміна не відкрита. Статус: ' + AShiftStatus.Status);
      FreeAndNil(AShiftStatus);
      Result := False;
    end;
  end;
end;



// Додати в клас TReceiptWebAPI
procedure TReceiptWebAPI.SaveShiftToFile(const AShiftId: string);
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(GetAppConfigDir(False) + 'shift_state.ini');
  try
    IniFile.WriteString('Shift', 'CurrentShiftId', AShiftId);
    IniFile.WriteDateTime('Shift', 'LastUpdate', Now);
  finally
    IniFile.Free;
  end;
end;



function TReceiptWebAPI.LoadShiftFromFile: string;
var
  IniFile: TIniFile;
  ConfigPath: string;
  LastUpdate: TDateTime;
begin
  Result := '';
  ConfigPath := GetAppConfigDir(False) + 'shift_state.ini';

  if not FileExists(ConfigPath) then
  begin
    Log('Файл стану зміни не існує');
    Exit;
  end;

  try
    IniFile := TIniFile.Create(ConfigPath);
    try
      // Читаємо ID зміни з правильним ключем
      Result := IniFile.ReadString('Shift', 'CurrentShiftId', '');
      LastUpdate := IniFile.ReadDateTime('Shift', 'LastUpdate', 0);

      // Перевірка 1: чи не порожній рядок
      if Result = '' then
      begin
        Log('CurrentShiftId порожній у файлі');
        Exit;
      end;

      // Перевірка 2: коректність довжини UUID (36 символів)
      if Length(Result) <> 36 then
      begin
        Log('Недійсний CurrentShiftId у файлі: ' + Result + ' (довжина: ' + IntToStr(Length(Result)) + ')');
        Result := '';
        Exit;
      end;

      // Перевірка 3: формат UUID (містить дефіси у правильних позиціях)
      if (Result[9] <> '-') or (Result[14] <> '-') or
         (Result[19] <> '-') or (Result[24] <> '-') then
      begin
        Log('Недійсний формат UUID: ' + Copy(Result, 1, 8) + '...');
        Result := '';
        Exit;
      end;

      // Перевірка 4: чи не застарілі дані (>24 годин)
      if HoursBetween(Now, LastUpdate) > 24 then
      begin
        Log('Дані зміни застаріли (>24 год). Очищаємо: ' + Copy(Result, 1, 8) + '...');
        Result := '';
        Exit;
      end;

      Log('Успішно завантажено CurrentShiftId: ' + Copy(Result, 1, 8) + '...');

    finally
      IniFile.Free;
    end;
  except
    on E: Exception do
    begin
      Log('Помилка читання файлу стану: ' + E.Message);
      Result := '';
    end;
  end;
end;


function TReceiptWebAPI.CheckCashRegisterMode(const ACashRegisterId: string;
  out AResponse: string): Boolean;
var
  CashRegisterStatus: TCashRegisterStatus;
begin
  Result := False;

  if GetCashRegisterStatusCurl(ACashRegisterId, AResponse, CashRegisterStatus) then
  begin
    try
      if Assigned(CashRegisterStatus) then
      begin
        Log('Режим каси: OfflineMode=' + BoolToStr(CashRegisterStatus.OfflineMode, True) +
            ', StayOffline=' + BoolToStr(CashRegisterStatus.StayOffline, True));

        // Перевіряємо, чи підтримується онлайн-режим
        Result := not CashRegisterStatus.StayOffline;

        if not Result then
          AResponse := 'Каса налаштована на роботу тільки в офлайн-режимі';
      end;
    finally
      if Assigned(CashRegisterStatus) then
        FreeAndNil(CashRegisterStatus);
    end;
  end;
end;


function TReceiptWebAPI.InitializeCashRegister(const AFiscalNumber: string; out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  CashRegistersArray: TJSONArray;
  I: Integer;
  CashRegisterObj: TJSONObject;
  SomeArrayVar: TCashRegisterArray;
begin
  Result := False;
  AResponse := '';
  FCurrentCashRegisterId := '';

  // Отримуємо список всіх кас
  if not GetCashRegistersListCurl(AResponse,SomeArrayVar) then
    Exit;

  try
    JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
    try
      JsonData := JsonParser.Parse as TJSONObject;

      // Перевіряємо структуру відповіді
      if JsonData.Find('results') <> nil then
        CashRegistersArray := JsonData.Arrays['results']
      else if JsonData.Find('cash_registers') <> nil then
        CashRegistersArray := JsonData.Arrays['cash_registers']
      else
        CashRegistersArray := nil;

      if Assigned(CashRegistersArray) then
      begin
        for I := 0 to CashRegistersArray.Count - 1 do
        begin
          CashRegisterObj := CashRegistersArray.Objects[I];

          // Шукаємо касу за фіскальним номером
          if CashRegisterObj.Get('fiscal_number', '') = AFiscalNumber then
          begin
            FCurrentCashRegisterId := CashRegisterObj.Get('id', '');
            Result := True;
            Log('Знайдено касу: ' + FCurrentCashRegisterId + ' для фіскального номера: ' + AFiscalNumber);
            Break;
          end;
        end;

        if not Result then
        begin
          AResponse := 'Касу з фіскальним номером ' + AFiscalNumber + ' не знайдено';
          Log(AResponse);
        end;
      end
      else
      begin
        AResponse := 'Не вдалося отримати список кас з відповіді сервера';
        Log(AResponse);
      end;
    finally
      JsonData.Free;
    end;
  except
    on E: Exception do
    begin
      AResponse := 'Помилка парсингу списку кас: ' + E.Message;
      Log(AResponse);
      Result := False;
    end;
  end;
end;

function TReceiptWebAPI.InitializeFirstCashRegister(out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  CashRegistersArray: TJSONArray;
  SomeArrayVar: TCashRegisterArray;
begin
  Result := False;
  AResponse := '';
  FCurrentCashRegisterId := '';

  // Отримуємо список всіх кас
  if not GetCashRegistersListCurl(AResponse,SomeArrayVar) then
    Exit;

  try
    JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
    try
      JsonData := JsonParser.Parse as TJSONObject;

      // Перевіряємо структуру відповіді
      if JsonData.Find('results') <> nil then
        CashRegistersArray := JsonData.Arrays['results']
      else if JsonData.Find('cash_registers') <> nil then
        CashRegistersArray := JsonData.Arrays['cash_registers']
      else
        CashRegistersArray := nil;

      if Assigned(CashRegistersArray) and (CashRegistersArray.Count > 0) then
      begin
        // Беремо першу доступну касу
        FCurrentCashRegisterId := CashRegistersArray.Objects[0].Get('id', '');
        Result := True;
        Log('Встановлено першу доступну касу: ' + FCurrentCashRegisterId);
      end
      else
      begin
        AResponse := 'Не знайдено жодної доступної каси';
        Log(AResponse);
      end;
    finally
      JsonData.Free;
    end;
  except
    on E: Exception do
    begin
      AResponse := 'Помилка парсингу списку кас: ' + E.Message;
      Log(AResponse);
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.BuildGoOnlineJsonData: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    // Пустий об'єкт для запиту
  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;



function TReceiptWebAPI.GoOnlineCurl(out AResponse: string): Boolean;
var
  Command: string;
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
begin
  Result := False;
  AResponse := '';

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    Command := Format('-X POST -H "accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "X-License-Key: %s" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d ''{}'' "%s/api/v1/cash-registers/go-online"',
       [FClientName, FClientVersion, FLicenseKey, FAuthInfo.Token, FBaseURL]);

    Log('GoOnlineCurl: Виконуємо команду: curl ' + Command);
    Result := ExecuteCurlCommand(Command,'GoOnlineCurl','POST /api/v1/cash-registers/go-online', AResponse);

    if Result then
    begin
      // Парсимо відповідь для перевірки статусу
      JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
      try
        JsonData := JsonParser.Parse as TJSONObject;
        Result := JsonData.Get('status', '') = 'ok';

        if Result then
          Log('Команда переходу в онлайн-режим успішно відправлена через curl')
        else
          Log('Невірний статус у відповіді curl: ' + AResponse);
      finally
        JsonData.Free;
      end;
    end
    else
    begin
      Log('Помилка виконання curl команди переходу: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GoOnlineCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TReceiptWebAPI.WaitForOnlineMode(out AResponse: string; ATimeoutSec: Integer = 300): Boolean;
var
  StartTime: TDateTime;
  ElapsedSeconds: Integer;
  CheckCount: Integer;
  CashRegisterStatus: TCashRegisterStatus;
  LastGoOnlineTime: TDateTime;
begin
  Result := False;
  AResponse := '';
  StartTime := Now;
  CheckCount := 0;
  LastGoOnlineTime := 0;

  Log('Очікування переходу каси в онлайн-режим');
  Log('Таймаут: ' + IntToStr(ATimeoutSec) + ' секунд');

  while SecondsBetween(Now, StartTime) < ATimeoutSec do
  begin
    Inc(CheckCount);
    Log('Перевірка статусу каси #' + IntToStr(CheckCount));

    // Перевіряємо статус каси
    if not GetCashRegisterStatusCurl(FCurrentCashRegisterId, AResponse, CashRegisterStatus) then
    begin
      Log('Помилка перевірки статусу каси: ' + AResponse);
      Sleep(60000); // Зачекати 1 хвилину перед наступною спробою
      Continue;
    end;

    if Assigned(CashRegisterStatus) then
    begin
      try
        Log('Статус каси: OfflineMode=' + BoolToStr(CashRegisterStatus.OfflineMode, True) +
            ', StayOffline=' + BoolToStr(CashRegisterStatus.StayOffline, True));

        // Перевіряємо, чи каса в онлайн-режимі
        if not CashRegisterStatus.OfflineMode then
        begin
          Result := True;
          Log('Каса успішно перейшла в онлайн-режим');
          Exit;
        end;

        // Якщо каса ще в офлайн-режимі, відправляємо команду go-online
        // (не частіше ніж раз на 2 хвилини через rate limit)
        if (MinutesBetween(Now, LastGoOnlineTime) >= 2) or (LastGoOnlineTime = 0) then
        begin
          Log('Відправляємо команду переходу в онлайн-режим...');
          if GoOnlineCurl(AResponse) then
          begin
            LastGoOnlineTime := Now;
            Log('Команда успішно відправлена, очікуємо...');
          end
          else
          begin
            Log('Помилка відправки команди: ' + AResponse);
          end;
        end
        else
        begin
          Log('Очікуємо перед наступною командою (rate limit 2 хвилини)');
        end;

      finally
        FreeAndNil(CashRegisterStatus);
      end;
    end;

    // Зачекати перед наступною перевіркою (1 хвилина)
    Sleep(60000);
    ElapsedSeconds := SecondsBetween(Now, StartTime);
    Log('Очікування... (' + IntToStr(ElapsedSeconds) + 'с/' +
        IntToStr(ATimeoutSec) + 'с)');
  end;

  Log('Час очікування переходу в онлайн-режим вийшов');
  AResponse := 'Таймаут очікування переходу каси в онлайн-режим';
end;

function TReceiptWebAPI.BuildGoOfflineJsonData: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    // Пустий об'єкт для запиту (аналогічно go-online)
    // Можна додати додаткові параметри якщо потрібно згідно документації
  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;



function TReceiptWebAPI.GoOfflineCurl(out AResponse: string): Boolean;
var
  Command: string;
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
  TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  AResponse := '';

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  StringList := TStringList.Create;
  try
    // Створюємо тимчасовий файл з правильним JSON
    TempFile := GetTempDir + 'go_offline_' + GenerateUUID + '.json';
    StringList.Text := '{}'; // Правильний JSON без зайвих лапок
    StringList.SaveToFile(TempFile);

    try
      // ВИПРАВЛЕНА команда - використовуємо файл замість -d '{}'
      Command := Format('-X POST -H "accept: application/json" -H "X-Client-Name: %s" ' +
                       '-H "X-Client-Version: %s" -H "X-License-Key: %s" ' +
                       '-H "Authorization: Bearer %s" -H "Content-Type: application/json" ' +
                       '--data-binary "@%s" "%s/api/v1/cash-registers/go-offline"',
        [FClientName, FClientVersion, FLicenseKey, FAuthInfo.Token, TempFile, FBaseURL]);

      Log('GoOfflineCurl: Виконуємо команду: curl ' + Command);
      Result := ExecuteCurlCommand(Command,'GoOfflineCurl','POST /api/v1/cash-registers/go-offline', AResponse);

      if Result then
      begin
        // Парсимо відповідь для перевірки статусу
        JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
        try
          JsonData := JsonParser.Parse as TJSONObject;
          Result := JsonData.Get('status', '') = 'ok';

          if Result then
          begin
            Log('Команда переходу в офлайн-режим успішно відправлена через curl');
            // ... інший код
          end
          else
          begin
            Log('Невірний статус у відповіді curl: ' + AResponse);
          end;
        finally
          JsonData.Free;
        end;
      end
      else
      begin
        Log('Помилка виконання curl команди переходу в офлайн: ' + AResponse);
      end;
    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GoOfflineCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TReceiptWebAPI.WaitForOfflineMode(out AResponse: string; ATimeoutSec: Integer = 300): Boolean;
var
  StartTime: TDateTime;
  ElapsedSeconds: Integer;
  CheckCount: Integer;
  CashRegisterStatus: TCashRegisterStatus;
  LastCheckTime: TDateTime;
begin
  Result := False;
  AResponse := '';
  StartTime := Now;
  CheckCount := 0;
  LastCheckTime := 0;

  Log('Очікування переходу каси в офлайн-режим');
  Log('Таймаут: ' + IntToStr(ATimeoutSec) + ' секунд');

  while SecondsBetween(Now, StartTime) < ATimeoutSec do
  begin
    Inc(CheckCount);
    Log('Перевірка статусу каси #' + IntToStr(CheckCount));

    // Перевіряємо статус каси (не частіше ніж раз на 15 секунд)
    if (SecondsBetween(Now, LastCheckTime) >= 15) or (LastCheckTime = 0) then
    begin
      if not GetCashRegisterStatusCurl(FCurrentCashRegisterId, AResponse, CashRegisterStatus) then
      begin
        Log('Помилка перевірки статусу каси: ' + AResponse);
        Sleep(5000); // Зачекати 5 секунд перед наступною спробою
        Continue;
      end;

      if Assigned(CashRegisterStatus) then
      begin
        try
          Log('Статус каси: OfflineMode=' + BoolToStr(CashRegisterStatus.OfflineMode, True) +
              ', StayOffline=' + BoolToStr(CashRegisterStatus.StayOffline, True));

          // Перевіряємо, чи каса в офлайн-режимі
          if CashRegisterStatus.OfflineMode then
          begin
            Result := True;
            Log('Каса успішно перейшла в офлайн-режим');
            Exit;
          end;

          LastCheckTime := Now;
        finally
          FreeAndNil(CashRegisterStatus);
        end;
      end;
    end;

    // Зачекати перед наступною перевіркою (5 секунд)
    Sleep(5000);
    ElapsedSeconds := SecondsBetween(Now, StartTime);
    Log('Очікування... (' + IntToStr(ElapsedSeconds) + 'с/' +
        IntToStr(ATimeoutSec) + 'с)');
  end;

  Log('Час очікування переходу в офлайн-режим вийшов');
  AResponse := 'Таймаут очікування переходу каси в офлайн-режим';
end;

function TReceiptWebAPI.GetZReportCurl(const AShiftId: string; out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" -H "X-Client-Version: %s" -H "Authorization: Bearer %s" "%s/api/v1/shifts/%s/z-report"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, AShiftId]);

    Result := ExecuteCurlCommand(Command,'GetZReportCurl','GET /api/v1/shifts/ShiftID/z-report', AResponse);
  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;



function TReceiptWebAPI.CloseCurrentShiftCurl(out AResponse: string; out AShiftStatus: TShiftStatus): Boolean;
var
  Command, TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  AResponse := '';
  AShiftStatus := nil;

  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  StringList := TStringList.Create;
  try
    TempFile := GetTempDir + 'close_shift_' + GenerateUUID + '.json';
    StringList.Text := '{}';
    StringList.SaveToFile(TempFile);

    try
      Command := Format('-X POST -H "accept: application/json" ' +
                       '-H "X-Client-Name: %s" -H "X-Client-Version: %s" ' +
                       '-H "Authorization: Bearer %s" -H "Content-Type: application/json" ' +
                       '--data-binary "@%s" "%s/api/v1/shifts/close"',
        [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL]);

      Result := ExecuteCurlCommand(Command,'CloseCurrentShiftCurl','POST /api/v1/shifts/close', AResponse);

      if Result then
      begin
        Result := ParseShiftStatus(AResponse, AShiftStatus);

        // ДОДАНО: Скидання балансу при закритті поточної зміни
        if Result and Assigned(AShiftStatus) and (AShiftStatus.Status = 'CLOSED') then
        begin
          FCurrentBalance := 0;
          FLastBalanceUpdate := Now;
          FCurrentShiftId := '';
          Log('CloseCurrentShiftCurl: Поточну зміну закрито, баланс скинуто до 0');
        end;
      end;

    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.CashOperationTypeToString(AOperationType: TCashOperationType): string;
begin
  case AOperationType of
    cotCashIn: Result := 'CASH_IN';
    cotCashOut: Result := 'CASH_OUT';
  else
    Result := 'CASH_IN';
  end;
end;

function TReceiptWebAPI.BuildCashOperationJsonData(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('type', CashOperationTypeToString(AOperationType));
    Result.Add('amount', AAmount);

    if ADescription <> '' then
      Result.Add('description', ADescription);

    // Додаємо обов'язкові поля для чека
    Result.Add('id', GenerateUUID);
    Result.Add('cashier_name', 'Касир'); // Замініть на реальне ім'я касира
    Result.Add('department', '1'); // Замініть на реальний відділ

  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;


function TReceiptWebAPI.CashInCurl(AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
begin
  Result := CashOperationCurl(cotCashIn, AAmount, ADescription, AResponse, AReceiptResponse);
end;


function TReceiptWebAPI.CashOutCurl(AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
begin
  Result := CashOperationCurl(cotCashOut, AAmount, ADescription, AResponse, AReceiptResponse);
end;



function TReceiptWebAPI.CashOperationCurl(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile, OperationTypeStr: string;
  StringList: TStringList;
begin
  Result := False;
  AReceiptResponse := nil;

  // Перевіряємо чи токен дійсний
  if not IsTokenValid then
  begin
    // ЄДИНИЙ спосіб отримати новий токен - повторний логін
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  // Перевіряємо наявність ID каси
  if FCurrentCashRegisterId = '' then
  begin
    AResponse := 'Cash register ID not set';
    Log('CashOperationCurl: ' + AResponse);
    Exit;
  end;

  JsonData := nil;
  StringList := TStringList.Create;
  try
    // Визначаємо тип операції
    case AOperationType of
      cotCashIn: OperationTypeStr := 'CASH_IN';
      cotCashOut: OperationTypeStr := 'CASH_OUT';
    else
      OperationTypeStr := 'CASH_IN';
    end;

    // Формуємо JSON з даними операції згідно PHP SDK
    JsonData := TJSONObject.Create;
    try
      // Основні поля згідно PHP SDK
      JsonData.Add('value', AAmount);
      JsonData.Add('currency', 'UAH');

      if ADescription <> '' then
        JsonData.Add('description', ADescription)
      else
        JsonData.Add('description', 'Готівкова операція');

      JsonData.Add('type', OperationTypeStr);

      // Додаткові поля для коректної роботи
      JsonData.Add('id', GenerateUUID);
      JsonData.Add('cashier_name', 'Касир'); // Замініть на реальне ім'я
      JsonData.Add('department', '1');

      JsonString := JsonData.AsJSON;
      Log('CashOperationCurl: JSON data: ' + Copy(JsonString, 1, 200) + '...');

    finally
      JsonData.Free;
    end;

    // Створюємо тимчасовий файл для JSON даних
    TempFile := GetTempDir + 'cash_operation_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // ВИПРАВЛЕНИЙ URL - використовуємо ендпоінт згідно PHP SDK
      Command := Format('-X POST -H "Content-Type: application/json" ' +
                       '-H "Accept: application/json" ' +
                       '-H "X-Client-Name: %s" ' +
                       '-H "X-Client-Version: %s" ' +
                       '-H "Authorization: Bearer %s" ' +
                       '--data-binary "@%s" ' +
                       '"%s/api/cash-registers/%s/cash"',
        [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL, FCurrentCashRegisterId]);

      Log('CashOperationCurl: Виконуємо команду: curl ' + Command);

      // Виконуємо curl команду
      Result := ExecuteCurlCommand(Command, 'CashOperationCurl', 'POST /api/cash-registers/CashRegisterID/cash', AResponse);

      // Аналізуємо відповідь
      if Result then
      begin
        Log('CashOperationCurl: Відповідь сервера: ' + Copy(AResponse, 1, 300));

        // Перевіряємо наявність помилок
        if CheckResponseForErrors(AResponse) then
        begin
          Log('CashOperationCurl: Сервер повернув помилку: ' + Copy(AResponse, 1, 200));
          Result := False;
        end
        else
        begin
          // Спробуємо парсити відповідь як чек
          AReceiptResponse := TReceiptResponse.Create;
          Result := AReceiptResponse.ParseFromJSON(AResponse, Self);

          if not Result then
          begin
            // Якщо не вдалося розпарсити як чек, перевіряємо інші формати
            if (Pos('"id"', AResponse) > 0) and (Pos('"type"', AResponse) > 0) then
            begin
              // Можливо це відповідь про успішну операцію
              Log('CashOperationCurl: Готівкова операція успішна (не чек)');
              Result := True;
            end
            else
            begin
              Log('CashOperationCurl: Не вдалося розпарсити відповідь');
              FreeAndNil(AReceiptResponse);
            end;
          end
          else
          begin
            Log('CashOperationCurl: Операція успішна, отримано чек');
          end;

          // Після успішної операції оновлюємо баланс
          if Result then
          begin
            FLastBalanceUpdate := 0;
            GetCurrentBalance(AResponse);
          end;
        end;
      end
      else
      begin
        Log('CashOperationCurl: Помилка виконання curl команди: ' + AResponse);

        // Альтернативна спроба - інший ендпоінт
        Log('CashOperationCurl: Спробуємо альтернативний ендпоінт...');
        Result := TryAlternativeCashOperation(AOperationType, AAmount, ADescription, AResponse, AReceiptResponse);
      end;

    finally
      // Видаляємо тимчасовий файл
      if FileExists(TempFile) then
      begin
        DeleteFile(TempFile);
        Log('CashOperationCurl: Тимчасовий файл видалено');
      end;
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('CashOperationCurl: Виняток: ' + E.Message);
      Result := False;

      if Assigned(AReceiptResponse) then
        FreeAndNil(AReceiptResponse);
    end;
  end;
end;
function TReceiptWebAPI.CreateCashOperation(AOperationType: TCashOperationType; AAmount: Integer; ADescription: string): TCashOperation;
begin
  Result := TCashOperation.Create;
  Result.OperationType := AOperationType;
  Result.Amount := AAmount;
  Result.Description := ADescription;
end;

// Додайте цей метод до TReceiptWebAPI
function TReceiptWebAPI.GetShiftBalance(out ABalance: Integer; out AResponse: string): Boolean;
var
  ShiftStatus: TShiftStatus;
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  BalanceObj: TJSONObject;
begin
  Result := False;
  ABalance := 0;
  AResponse := '';

  if FCurrentShiftId = '' then
  begin
    AResponse := 'Зміна не відкрита';
    Exit;
  end;

  // Отримуємо детальну інформацію про зміну
  if GetShiftStatusCurl(FCurrentShiftId, AResponse, ShiftStatus) then
  begin
    try
      if Assigned(ShiftStatus) and (ShiftStatus.Status = 'OPENED') then
      begin
        // Спробуємо отримати баланс зі звіту про зміну
        if GetShiftReportCurl(FCurrentShiftId, AResponse, FLastShiftReport) then
        begin
          if Assigned(FLastShiftReport) then
          begin
            ABalance := FLastShiftReport.Balance;
            Result := True;
          end;
        end
        else
        begin
          // Альтернативний спосіб - отримати баланс через API балансу
          Result := GetShiftBalanceDirect(ABalance, AResponse);
        end;
      end;
    finally
      if Assigned(ShiftStatus) then
        FreeAndNil(ShiftStatus);
    end;
  end;
end;

// Цей метод не працює - ендпоінт /shifts/{id}/balance не існує
function TReceiptWebAPI.GetShiftBalanceDirect(out ABalance: Integer; out AResponse: string): Boolean;
begin
  Result := False;
  ABalance := 0;
  AResponse := 'Method not supported by API';
end;

procedure TReceiptWebAPI.SaveBalanceData(JsonData: TJSONObject);
var
  TaxesArray, PaymentsArray: TJSONArray;
  I: Integer;
  TaxObj, PaymentObj: TJSONObject;
begin
  if not Assigned(FBalanceData) then
    FBalanceData := TShiftBalanceData.Create
  else
  begin
    // Очищаємо попередні дані
    for I := 0 to High(FBalanceData.Taxes) do
      FreeAndNil(FBalanceData.Taxes[I]);
    SetLength(FBalanceData.Taxes, 0);

    for I := 0 to High(FBalanceData.Payments) do
      FreeAndNil(FBalanceData.Payments[I]);
    SetLength(FBalanceData.Payments, 0);
  end;

  with FBalanceData do
  begin
    // Основні поля балансу з перевірками
    Initial := JsonData.Get('initial', 0);
    Balance := JsonData.Get('balance', 0);
    CashSales := JsonData.Get('cash_sales', 0);
    CardSales := JsonData.Get('card_sales', 0);
    DiscountsSum := JsonData.Get('discounts_sum', 0);
    ExtraChargeSum := JsonData.Get('extra_charge_sum', 0);
    CashReturns := JsonData.Get('cash_returns', 0);
    CardReturns := JsonData.Get('card_returns', 0);
    ServiceIn := JsonData.Get('service_in', 0);
    ServiceOut := JsonData.Get('service_out', 0);
    SalesRoundUp := JsonData.Get('sales_round_up', 0);
    SalesRoundDown := JsonData.Get('sales_round_down', 0);
    ReturnsRoundUp := JsonData.Get('returns_round_up', 0);
    ReturnsRoundDown := JsonData.Get('returns_round_down', 0);
    UpdatedAt := ParseDateTime(JsonData.Get('updated_at', ''));

    // Додаткові поля з API
    SellReceiptsCount := JsonData.Get('sell_receipts_count', 0);
    ReturnReceiptsCount := JsonData.Get('return_receipts_count', 0);
    CashWithdrawalReceiptsCount := JsonData.Get('cash_withdrawal_receipts_count', 0);
    LastReceiptId := JsonData.Get('last_receipt_id', '');

    // Парсимо податки - ТЕПЕР З ПЕРЕВІРКАМИ
    if JsonData.Find('taxes') <> nil then
    begin
      TaxesArray := JsonData.Arrays['taxes'];
      if Assigned(TaxesArray) then
      begin
        SetLength(Taxes, TaxesArray.Count);
        for I := 0 to TaxesArray.Count - 1 do
        begin
          TaxObj := TaxesArray.Objects[I];
          Taxes[I] := TShiftTax.Create;

          // Основні поля податку з перевірками
          Taxes[I].Id := TaxObj.Get('id', '');
          Taxes[I].Code := TaxObj.Get('code', 0);
          Taxes[I].LabelText := TaxObj.Get('label', '');
          Taxes[I].Symbol := TaxObj.Get('symbol', '');
          Taxes[I].Rate := TaxObj.Get('rate', 0.0);
          Taxes[I].ExtraRate := TaxObj.Get('extra_rate', 0.0);
          Taxes[I].Included := TaxObj.Get('included', False);
          Taxes[I].NoVat := TaxObj.Get('no_vat', False);
          Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');

          // Фінансові показники податку з перевірками
          Taxes[I].SellSum := TaxObj.Get('sell_sum', 0);
          Taxes[I].ReturnSum := TaxObj.Get('return_sum', 0);
          Taxes[I].SalesTurnover := TaxObj.Get('sales_turnover', 0);
          Taxes[I].ReturnsTurnover := TaxObj.Get('returns_turnover', 0);
          Taxes[I].Sales := TaxObj.Get('sales', 0.0);
          Taxes[I].Returns := TaxObj.Get('returns', 0.0);
          Taxes[I].TaxSum := TaxObj.Get('value', 0.0);
          Taxes[I].ExtraTaxSum := TaxObj.Get('extra_value', 0.0);

          // Додаткові поля
          Taxes[I].SetupDate := ParseDateTime(TaxObj.Get('setup_date', ''));
        end;
      end;
    end
    else
    begin
      Log('SaveBalanceData: Поле "taxes" не знайдено у відповіді');
      SetLength(Taxes, 0);
    end;

    // Парсимо платежі - ТЕПЕР З ПЕРЕВІРКАМИ
    if JsonData.Find('payments') <> nil then
    begin
      PaymentsArray := JsonData.Arrays['payments'];
      if Assigned(PaymentsArray) then
      begin
        SetLength(Payments, PaymentsArray.Count);
        for I := 0 to PaymentsArray.Count - 1 do
        begin
          PaymentObj := PaymentsArray.Objects[I];
          Payments[I] := TShiftPayment.Create;

          // Основні поля платежу з перевірками
          Payments[I].PaymentType := PaymentObj.Get('type', '');
          Payments[I].ProviderType := PaymentObj.Get('provider_type', '');
          Payments[I].Code := PaymentObj.Get('code', 0);
          Payments[I].LabelText := PaymentObj.Get('label', '');

          // Фінансові показники платежу з перевірками
          Payments[I].SellSum := PaymentObj.Get('sell_sum', 0);
          Payments[I].ReturnSum := PaymentObj.Get('return_sum', 0);
          Payments[I].ServiceIn := PaymentObj.Get('service_in', 0);
          Payments[I].ServiceOut := PaymentObj.Get('service_out', 0);
          Payments[I].CashWithdrawal := PaymentObj.Get('cash_withdrawal', 0);
          Payments[I].CashWithdrawalCommission := PaymentObj.Get('cash_withdrawal_commission', 0);
        end;
      end;
    end
    else
    begin
      Log('SaveBalanceData: Поле "payments" не знайдено у відповіді');
      SetLength(Payments, 0);
    end;

    // Додаткові дані з перевірками
    if JsonData.Find('shift_info') <> nil then
    begin
      with JsonData.Objects['shift_info'] do
      begin
        ShiftId := Get('id', '');
        ShiftSerial := Get('serial', 0);
        ShiftStatus := Get('status', '');
        ShiftOpenedAt := ParseDateTime(Get('opened_at', ''));
        ShiftClosedAt := ParseDateTime(Get('closed_at', ''));
      end;
    end;

    // Інформація про касу з перевірками
    if JsonData.Find('cash_register') <> nil then
    begin
      with JsonData.Objects['cash_register'] do
      begin
        CashRegisterId := Get('id', '');
        CashRegisterFiscalNumber := Get('fiscal_number', '');
        CashRegisterNumber := Get('number', '');
      end;
    end;

    // Інформація про касира з перевірками
    if JsonData.Find('cashier') <> nil then
    begin
      with JsonData.Objects['cashier'] do
      begin
        CashierId := Get('id', '');
        CashierName := Get('full_name', '');
        CashierNIN := Get('nin', '');
      end;
    end;
  end;

  Log('Дані балансу успішно збережено. Баланс: ' +
      FloatToStrF(FBalanceData.Balance / 100, ffNumber, 10, 2) + ' грн');
end;

function TReceiptWebAPI.GetBalanceData: TShiftBalanceData;
begin
  Result := FBalanceData;
end;

function TReceiptWebAPI.GetShiftZReportCurl(const AShiftId: string;
  out AResponse: string; out AShiftReport: TShiftReport): Boolean;
var
  Command: string;
begin
  Result := False;
  AShiftReport := nil;
  AResponse := '';

  if not IsTokenValid then
  begin
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    // ВИПРАВЛЕНО: Z-звіт теж через /api/v1/reports, але для закритої зміни
    // У реальності Z-звіт створюється автоматично при закритті зміни
    Command := Format('-X GET -H "Accept: application/json" -H "X-Client-Name: %s" ' +
                     '-H "X-Client-Version: %s" -H "Authorization: Bearer %s" ' +
                     '"%s/api/v1/shifts/%s/z-report"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, AShiftId]);

    Log('GetShiftZReportCurl: Виконуємо команду: curl ' + Command);
    Result := ExecuteCurlCommand(Command, 'GetShiftZReportCurl', 'GET /api/v1/shifts/ShiftID/z-report', AResponse);

    if Result then
    begin
      // Для Z-звіту використовуємо той же парсер, що і для X-звіту
      Result := ParseShiftReport(AResponse, AShiftReport);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetShiftZReportCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.GetShiftXReportCurl(const AShiftId: string;
  out AResponse: string; out AShiftReport: TShiftReport): Boolean;
var
  Command: string;
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
  PaymentsArray, TaxesArray: TJSONArray;
  I: Integer;
  PaymentObj, TaxObj: TJSONObject;
begin
  Result := False;
  AShiftReport := nil;
  AResponse := '';

  if not IsTokenValid then
  begin
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    // ВИПРАВЛЕНО: Використовуємо правильний ендпоінт для X-звіту
    Command := Format('-X POST -H "Accept: application/json" -H "X-Client-Name: %s" ' +
                     '-H "X-Client-Version: %s" -H "Authorization: Bearer %s" ' +
                     '"%s/api/v1/reports"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL]);

    Log('GetShiftXReportCurl: Виконуємо команду: curl ' + Command);
    Result := ExecuteCurlCommand(Command, 'GetShiftXReportCurl', 'POST /api/v1/reports', AResponse);

    if Result then
    begin
      // Перевіряємо наявність помилок
      if CheckResponseForErrors(AResponse) then
      begin
        Log('GetShiftXReportCurl: Сервер повернув помилку: ' + AResponse);
        Result := False;
        Exit;
      end;

      // Парсимо відповідь
      JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
      try
        JsonData := JsonParser.Parse as TJSONObject;

        AShiftReport := TShiftReport.Create;
        try
          // Основні поля звіту згідно документації
          AShiftReport.Id := JsonData.Get('id', '');
          AShiftReport.Serial := JsonData.Get('serial', 0);
          AShiftReport.SellReceiptsCount := JsonData.Get('sell_receipts_count', 0);
          AShiftReport.ReturnReceiptsCount := JsonData.Get('return_receipts_count', 0);
          AShiftReport.CashWithdrawalReceiptsCount := JsonData.Get('cash_withdrawal_receipts_count', 0);
          AShiftReport.LastReceiptId := JsonData.Get('last_receipt_id', '');
          AShiftReport.Initial := JsonData.Get('initial', 0);
          AShiftReport.Balance := JsonData.Get('balance', 0);
          AShiftReport.SalesRoundUp := JsonData.Get('sales_round_up', 0);
          AShiftReport.SalesRoundDown := JsonData.Get('sales_round_down', 0);
          AShiftReport.ReturnsRoundUp := JsonData.Get('returns_round_up', 0);
          AShiftReport.ReturnsRoundDown := JsonData.Get('returns_round_down', 0);
          AShiftReport.CreatedAt := ParseDateTime(JsonData.Get('created_at', ''));

          // Нові поля згідно документації
          AShiftReport.DiscountsSum := JsonData.Get('discounts_sum', 0);
          AShiftReport.ExtraChargeSum := JsonData.Get('extra_charge_sum', 0);

          // Парсимо платежі
          if (JsonData.Find('payments') <> nil) and
             (JsonData.Items[JsonData.IndexOfName('payments')].JSONType = jtArray) then
          begin
            PaymentsArray := JsonData.Arrays['payments'];
            if Assigned(PaymentsArray) then
            begin
              SetLength(AShiftReport.Payments, PaymentsArray.Count);
              for I := 0 to PaymentsArray.Count - 1 do
              begin
                if PaymentsArray.Items[I].JSONType = jtObject then
                begin
                  PaymentObj := PaymentsArray.Objects[I];
                  AShiftReport.Payments[I] := TShiftPayment.Create;

                  AShiftReport.Payments[I].PaymentType := PaymentObj.Get('type', '');
                  AShiftReport.Payments[I].ProviderType := PaymentObj.Get('provider_type', '');
                  AShiftReport.Payments[I].Code := PaymentObj.Get('code', 0);
                  AShiftReport.Payments[I].LabelText := PaymentObj.Get('label', '');
                  AShiftReport.Payments[I].SellSum := PaymentObj.Get('sell_sum', 0);
                  AShiftReport.Payments[I].ReturnSum := PaymentObj.Get('return_sum', 0);
                  AShiftReport.Payments[I].ServiceIn := PaymentObj.Get('service_in', 0);
                  AShiftReport.Payments[I].ServiceOut := PaymentObj.Get('service_out', 0);
                  AShiftReport.Payments[I].CashWithdrawal := PaymentObj.Get('cash_withdrawal', 0);
                  AShiftReport.Payments[I].CashWithdrawalCommission := PaymentObj.Get('cash_withdrawal_commission', 0);
                end;
              end;
            end;
          end
          else
          begin
            SetLength(AShiftReport.Payments, 0);
          end;

          // Парсимо податки
          if (JsonData.Find('taxes') <> nil) and
             (JsonData.Items[JsonData.IndexOfName('taxes')].JSONType = jtArray) then
          begin
            TaxesArray := JsonData.Arrays['taxes'];
            if Assigned(TaxesArray) then
            begin
              SetLength(AShiftReport.Taxes, TaxesArray.Count);
              for I := 0 to TaxesArray.Count - 1 do
              begin
                if TaxesArray.Items[I].JSONType = jtObject then
                begin
                  TaxObj := TaxesArray.Objects[I];
                  AShiftReport.Taxes[I] := TShiftTax.Create;

                  // Основні поля податку
                  AShiftReport.Taxes[I].Id := TaxObj.Get('id', '');
                  AShiftReport.Taxes[I].Code := TaxObj.Get('code', 0);
                  AShiftReport.Taxes[I].LabelText := TaxObj.Get('label', '');
                  AShiftReport.Taxes[I].Symbol := TaxObj.Get('symbol', '');
                  AShiftReport.Taxes[I].Rate := TaxObj.Get('rate', 0.0);
                  AShiftReport.Taxes[I].SellSum := TaxObj.Get('sell_sum', 0);
                  AShiftReport.Taxes[I].ReturnSum := TaxObj.Get('return_sum', 0);
                  AShiftReport.Taxes[I].SalesTurnover := TaxObj.Get('sales_turnover', 0);
                  AShiftReport.Taxes[I].ReturnsTurnover := TaxObj.Get('returns_turnover', 0);
                  AShiftReport.Taxes[I].NoVat := TaxObj.Get('no_vat', False);
                  AShiftReport.Taxes[I].AdvancedCode := TaxObj.Get('advanced_code', '');
                  AShiftReport.Taxes[I].SetupDate := ParseDateTime(TaxObj.Get('setup_date', ''));
                end;
              end;
            end;
          end
          else
          begin
            SetLength(AShiftReport.Taxes, 0);
          end;

          Log('GetShiftXReportCurl: X-звіт успішно отримано. ID: ' + AShiftReport.Id);
          Result := True;

        except
          on E: Exception do
          begin
            Log('GetShiftXReportCurl: Помилка парсингу звіту: ' + E.Message);
            FreeAndNil(AShiftReport);
            Result := False;
          end;
        end;

      finally
        JsonData.Free;
      end;
    end
    else
    begin
      Log('GetShiftXReportCurl: Помилка виконання запиту: ' + AResponse);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetShiftXReportCurl: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.GetCurrentBalance(out AResponse: string): Integer;
var
  BalanceFromAPI: Integer;
  NeedUpdate: Boolean;
begin
  // Проверяем, нужно ли обновлять баланс
  NeedUpdate := (SecondsBetween(Now, FLastBalanceUpdate) > FBalanceUpdateInterval) or
                (FCurrentShiftId = '') or
                (FCurrentBalance = 0);

  if not NeedUpdate then
  begin
    Result := FCurrentBalance;
    AResponse := 'OK (cached)';
    Exit;
  end;

  // Пытаемся получить баланс разными способами
  if GetShiftBalanceDirect(BalanceFromAPI, AResponse) then
  begin
    FCurrentBalance := BalanceFromAPI;
    FLastBalanceUpdate := Now;
    Result := FCurrentBalance;
    Log('Баланс обновлен: ' + FloatToStrF(Result / 100, ffNumber, 10, 2) + ' грн');
  end
  else if GetShiftBalance(BalanceFromAPI, AResponse) then
  begin
    FCurrentBalance := BalanceFromAPI;
    FLastBalanceUpdate := Now;
    Result := FCurrentBalance;
    Log('Баланс обновлен (через отчет): ' + FloatToStrF(Result / 100, ffNumber, 10, 2) + ' грн');
  end
  else
  begin
    // Если не удалось получить баланс, возвращаем кэшированное значение
    Result := FCurrentBalance;
    Log('Не удалось обновить баланс, используется кэш: ' +
        FloatToStrF(Result / 100, ffNumber, 10, 2) + ' грн');
  end;
end;

function TReceiptWebAPI.SendReceiptCurl(AReceipt: TReceipt; out AResponse: string;
  out AReceiptResponse: TReceiptResponse): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile, ValidationError, Endpoint: string;
  StringList: TStringList;
  i: integer;
begin
  // ДЕТАЛЬНЕ ЛОГУВАННЯ СТВОРЕНОГО З БАЗИ ЧЕКА
  Log('=== ДЕТАЛЬНА ІНФОРМАЦІЯ ПРО ЧЕК ПЕРЕД ВІДПРАВКОЮ ===');
  Log('Загальна сума: ' + IntToStr(AReceipt.TotalSum) + ' коп');
  Log('Кількість товарів: ' + IntToStr(Length(AReceipt.Goods)));
  Log('Кількість оплат: ' + IntToStr(Length(AReceipt.Payments)));

  for i := 0 to High(AReceipt.Goods) do
  begin
    if Assigned(AReceipt.Goods[i]) and Assigned(AReceipt.Goods[i].Good) then
    begin
      Log(Format('Товар %d: %s - Ціна: %d коп, Кількість: %d, Сума: %d коп', [
        i, AReceipt.Goods[i].Good.Name,
        AReceipt.Goods[i].Good.Price,
        AReceipt.Goods[i].Quantity,
        AReceipt.Goods[i].TotalSum
      ]));
    end
    else
    begin
      Log(Format('❌ ПОМИЛКА: Товар %d не ініціалізований', [i]));
    end;
  end;

  for i := 0 to High(AReceipt.Payments) do
  begin
    if Assigned(AReceipt.Payments[i]) then
    begin
      Log(Format('Оплата %d: Тип=%d, Сума=%d коп', [
        i, Ord(AReceipt.Payments[i].PaymentType), AReceipt.Payments[i].Value
      ]));
    end
    else
    begin
      Log(Format('❌ ПОМИЛКА: Оплата %d не ініціалізована', [i]));
    end;
  end;
  Log('=== КІНЕЦЬ ДЕТАЛЬНОЇ ІНФОРМАЦІЇ ===');

  // Перевірка критичних полів чека
  Log('=== ПЕРЕВІРКА КРИТИЧНИХ ПОЛІВ ЧЕКА ===');
  Log('OrderId: ' + AReceipt.OrderId);
  Log('RelatedReceiptId: ' + AReceipt.RelatedReceiptId);
  Log('PreviousReceiptId: ' + AReceipt.PreviousReceiptId);
  Log('Context: ' + AReceipt.Context);
  Log('CashierName: ' + AReceipt.CashierName);
  Log('Departament: ' + AReceipt.Departament);
  Log('TotalSum: ' + IntToStr(AReceipt.TotalSum));
  Log('TotalPayment: ' + IntToStr(AReceipt.TotalPayment));
  Log('=== КІНЕЦЬ ПЕРЕВІРКИ ===');

  Result := False;
  AReceiptResponse := nil;
  JsonData := nil;
  StringList := TStringList.Create;

  try
    try
      // 1. Перевірка вхідних параметрів
      if not Assigned(AReceipt) then
      begin
        AResponse := 'Помилка: AReceipt не ініціалізований';
        Log('❌ SendReceiptCurl: ' + AResponse);
        Exit;
      end;

      // 2. Валідація структури чека (API-рівень)
      if not ValidateReceiptStructure(AReceipt, ValidationError) then
      begin
        AResponse := 'Помилка валідації: ' + ValidationError;
        Log('❌ SendReceiptCurl: ' + AResponse);
        Exit;
      end;

      // 3. Перевірка токена авторизації
      if not IsTokenValid then
      begin
        Log('⚠️ Токен недійсний, спроба оновлення...');
        if not LoginCurl(FUsername, FPassword, AResponse) then
        begin
          Log('❌ Потрібен повторний вхід: ' + AResponse);
          Exit;
        end
        else
        begin
          Log('✅ Токен успішно оновлено');
        end;
      end;

      // 4. Перевірка наявності ID каси
      if FCurrentCashRegisterId = '' then
      begin
        AResponse := 'Cash register ID not set';
        Log('❌ SendReceiptCurl: ' + AResponse);
        Exit;
      end;

      // 5. Вибір ендпоінта
      Endpoint := GetReceiptEndpoint(AReceipt.ReceiptType);
      Log(Format('Відправка чека типу %s', [ReceiptTypeToString(AReceipt.ReceiptType)]));

      // 6. Побудова JSON згідно з документацією Checkbox API
      try
        JsonData := BuildJsonDataCorrected(AReceipt);
        if not Assigned(JsonData) then
        begin
          AResponse := 'Помилка: не вдалося створити JSON дані';
          Log('❌ SendReceiptCurl: ' + AResponse);
          Exit;
        end;

        JsonString := JsonData.AsJSON;
        Log('SendReceiptCurl: JSON дані: ' + Copy(JsonString, 1, 500) + '...');
      except
        on E: Exception do
        begin
          AResponse := 'Помилка побудови JSON: ' + E.Message;
          Log('❌ SendReceiptCurl: ' + AResponse);
          Exit;
        end;
      end;

      // 7. Створення тимчасового файлу
      TempFile := GetTempDir + 'receipt_' + GenerateUUID + '.json';

      try
        StringList.Text := JsonString;
        StringList.SaveToFile(TempFile);
        Log('Тимчасовий файл створено: ' + TempFile);
      except
        on E: Exception do
        begin
          AResponse := 'Помилка збереження тимчасового файлу: ' + E.Message;
          Log('❌ SendReceiptCurl: ' + AResponse);
          Exit;
        end;
      end;

      // 8. Формування та виконання curl команди
      try
        Command := Format('-X POST -H "Content-Type: application/json" ' +
                         '-H "Accept: application/json" ' +
                         '-H "X-Client-Name: %s" ' +
                         '-H "X-Client-Version: %s" ' +
                         '-H "Authorization: Bearer %s" ' +
                         '--data-binary "@%s" ' +
                         '"%s%s"',
          [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL, Endpoint]);
        Log('Full JSON request: ' + JsonString);
        Log('Виконання curl команди: ' + Copy(Command, 1, 200) + '...');

        // 9. Виконання запиту
        Result := ExecuteCurlCommand(Command, 'SendReceiptCurl', Endpoint, AResponse);

        // 10. Аналіз відповіді API
        if Result then
        begin
          Log('✅ Отримано відповідь від сервера');

          // Перевірка на помилки API
          if CheckResponseForErrors(AResponse) then
          begin
            ParseAPIError(AResponse, AResponse);
            Log('❌ Помилка API: ' + AResponse);
            Result := False;

            // Детальний аналіз типових помилок
            if Pos('order_id', AResponse) > 0 then
              Log('💡 Рекомендація: Не передавайте order_id або використовуйте UUID');
            if Pos('context', AResponse) > 0 then
              Log('💡 Рекомендація: Не передавайте context');
            if Pos('uuid', AResponse) > 0 then
              Log('💡 Рекомендація: Перевірте формат UUID полів');
          end
          else
          begin
            // Спроба парсингу успішної відповіді
            try
              AReceiptResponse := TReceiptResponse.Create;
              Result := AReceiptResponse.ParseFromJSON(AResponse, Self);

              if Result then
              begin
                Log(Format('✅ Чек успішно створено. ID: %s, Фіскальний: %s',
                  [AReceiptResponse.Id, AReceiptResponse.FiscalCode]));

                // Оновлення балансу в API (не в БД!)
                FLastBalanceUpdate := 0;
                if not ForceBalanceUpdate(AResponse) then
                begin
                  Log('⚠️ Не вдалося оновити баланс, але чек створено');
                end;
              end
              else
              begin
                Log('❌ Не вдалося розпарсити відповідь сервера');
                FreeAndNil(AReceiptResponse);
              end;
            except
              on E: Exception do
              begin
                Log('❌ Виняток при парсингу відповіді: ' + E.Message);
                FreeAndNil(AReceiptResponse);
                Result := False;
              end;
            end;
          end;
        end
        else
        begin
          Log('❌ Помилка виконання curl команди: ' + AResponse);

          // Аналіз мережевих помилок
          if IsNetworkError(AResponse) then
          begin
            Log('🌐 Мережева помилка - перевірте підключення до інтернету');
          end;
        end;

      except
        on E: Exception do
        begin
          AResponse := 'Виняток при виконанні curl: ' + E.Message;
          Log('❌ SendReceiptCurl: ' + AResponse);
          Result := False;
        end;
      end;

    finally
      // Очищення тимчасового файлу
      if FileExists(TempFile) then
      begin
        try
          DeleteFile(TempFile);
          Log('Тимчасовий файл видалено: ' + TempFile);
        except
          on E: Exception do
          begin
            Log('⚠️ Не вдалося видалити тимчасовий файл: ' + E.Message);
          end;
        end;
      end;
    end;

  except
    on E: Exception do
    begin
      AResponse := 'Критичний виняток у SendReceiptCurl: ' + E.Message;
      Log('❌ SendReceiptCurl: Критичний виняток: ' + E.Message);
      Log('Тип винятку: ' + E.ClassName);
      Result := False;

      // Гарантоване звільнення пам'яті
      if Assigned(AReceiptResponse) then
        FreeAndNil(AReceiptResponse);
    end;
  end;

  // Фінальне логування результату
  if Result then
  begin
    Log('🎉 SendReceiptCurl завершено УСПІШНО');
  end
  else
  begin
    Log('💥 SendReceiptCurl завершено З ПОМИЛКОЮ: ' + Copy(AResponse, 1, 200));
  end;

  // Остаточне очищення
  if Assigned(JsonData) then
    FreeAndNil(JsonData);
  if Assigned(StringList) then
    FreeAndNil(StringList);
end;

// Допоміжні методи API
function TReceiptWebAPI.GetReceiptEndpoint(AReceiptType: TReceiptType): string;
begin
  case AReceiptType of
    rtSell: Result := '/api/v1/receipts/sell';
    rtReturn: Result := '/api/v1/receipts/return';
    rtServiceIn: Result := '/api/v1/receipts/service-in';
    rtServiceOut: Result := '/api/v1/receipts/service-out';
    rtCashWithdrawal: Result := '/api/v1/receipts/cash-withdrawal';
  else
    Result := '/api/v1/receipts/sell';
  end;
end;

procedure TReceiptWebAPI.ParseAPIError(const AResponse: string; out AErrorDescription: string);
var
  JsonParser: TJSONParser;
  JsonData: TJSONObject;
begin
  try
    JsonParser := TJSONParser.Create(AResponse, [joUTF8]);
    try
      JsonData := JsonParser.Parse as TJSONObject;
      try
        AErrorDescription := JsonData.Get('message', '');
        if AErrorDescription = '' then
          AErrorDescription := JsonData.Get('detail', '');
        if AErrorDescription = '' then
          AErrorDescription := JsonData.Get('error', '');
        if AErrorDescription = '' then
          AErrorDescription := 'Невідома помилка API';
      finally
        JsonData.Free;
      end;
    finally
      JsonParser.Free;
    end;
  except
    AErrorDescription := AResponse;
  end;
end;

(*
function TReceiptWebAPI.ForceBalanceUpdate(out AResponse: string): Integer;
begin
  FLastBalanceUpdate := 0;
  Result := GetCurrentBalance(AResponse);
end;*)

function TReceiptWebAPI.ForceBalanceUpdate(out AResponse: string): Boolean;
var
  Balance: Integer;
begin
  Result := GetShiftBalance(Balance, AResponse);
  if Result then
  begin
    FCurrentBalance := Balance;
    FLastBalanceUpdate := Now;
  end;
end;

function TReceiptWebAPI.TryAlternativeCashOperation(AOperationType: TCashOperationType;
  AAmount: Integer; ADescription: string; out AResponse: string;
  out AReceiptResponse: TReceiptResponse): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile, OperationTypeStr: string;
  StringList: TStringList;
begin
  Result := False;
  AReceiptResponse := nil;

  StringList := TStringList.Create;
  try
    // Визначаємо тип операції
    case AOperationType of
      cotCashIn: OperationTypeStr := 'CASH_IN';
      cotCashOut: OperationTypeStr := 'CASH_OUT';
    else
      OperationTypeStr := 'CASH_IN';
    end;

    // Альтернативний формат JSON
    JsonData := TJSONObject.Create;
    try
      JsonData.Add('amount', AAmount);
      JsonData.Add('operation_type', OperationTypeStr);
      JsonData.Add('description', ADescription);
      JsonData.Add('currency', 'UAH');

      JsonString := JsonData.AsJSON;
    finally
      JsonData.Free;
    end;

    TempFile := GetTempDir + 'cash_alt_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // Альтернативний ендпоінт
      Command := Format('-X POST -H "Content-Type: application/json" ' +
                       '-H "Accept: application/json" ' +
                       '-H "Authorization: Bearer %s" ' +
                       '--data-binary "@%s" ' +
                       '"%s/api/v1/cash-operations"',
        [FAuthInfo.Token, TempFile, FBaseURL]);

      Log('TryAlternativeCashOperation: Виконуємо альтернативну команду: curl ' + Command);

      Result := ExecuteCurlCommand(Command, 'TryAlternativeCashOperation', 'POST /api/v1/cash-operations', AResponse);

      if Result then
      begin
        Log('TryAlternativeCashOperation: Альтернативна операція успішна');
        FLastBalanceUpdate := 0;
        GetCurrentBalance(AResponse);
      end;

    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  finally
    StringList.Free;
  end;
end;



function TReceiptWebAPI.CashIncome(AAmount: Integer; ADescription: string;
  out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
begin
  Result := ServiceCashOperation('SERVICE_IN', AAmount, ADescription, AResponse, AReceiptResponse);
end;

function TReceiptWebAPI.CashOutcome(AAmount: Integer; ADescription: string;
  out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
begin
  Result := ServiceCashOperation('SERVICE_OUT', AAmount, ADescription, AResponse, AReceiptResponse);
end;

function TReceiptWebAPI.ServiceCashOperation(AOperationType: string; AAmount: Integer;
  ADescription: string; out AResponse: string; out AReceiptResponse: TReceiptResponse): Boolean;
var
  JsonData, PaymentObj: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
begin
  Result := False;
  AReceiptResponse := nil;

  if not IsTokenValid then
  begin
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  JsonData := nil;
  StringList := TStringList.Create;
  try
    // Формуємо JSON згідно документації API
    JsonData := TJSONObject.Create;
    try
      // Обов'язкові поля
      JsonData.Add('id', GenerateUUID);

      // Блок payment
      PaymentObj := TJSONObject.Create;
      PaymentObj.Add('type', 'CASH');
      PaymentObj.Add('value', AAmount);
      JsonData.Add('payment', PaymentObj);

      // Опціональні поля
      if ADescription <> '' then
        JsonData.Add('description', ADescription);

      // Для SERVICE_OUT потрібно вказувати негативну суму
      if AOperationType = 'SERVICE_OUT' then
      begin
        PaymentObj.Add('value', -AAmount);
      end;

      JsonString := JsonData.AsJSON;
      Log('ServiceCashOperation: JSON data: ' + Copy(JsonString, 1, 200) + '...');
    finally
      JsonData.Free;
    end;

    TempFile := GetTempDir + 'service_cash_op_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // Використовуємо правильний ендпоінт для службових операцій
      Command := Format('-X POST -H "Content-Type: application/json" ' +
                       '-H "Accept: application/json" ' +
                       '-H "X-Client-Name: %s" ' +
                       '-H "X-Client-Version: %s" ' +
                       '-H "Authorization: Bearer %s" ' +
                       '--data-binary "@%s" ' +
                       '"%s/api/v1/receipts/service"',
        [FClientName, FClientVersion, FAuthInfo.Token, TempFile, FBaseURL]);

      Log('ServiceCashOperation: Executing: curl ' + Command);
      Result := ExecuteCurlCommand(Command, 'ServiceCashOperation',
                'POST /api/v1/receipts/service', AResponse);

      if Result then
      begin
        Log('ServiceCashOperation: Response: ' + Copy(AResponse, 1, 300));

        if CheckResponseForErrors(AResponse) then
        begin
          Log('ServiceCashOperation: Server error: ' + Copy(AResponse, 1, 200));
          Result := False;
        end
        else
        begin
          AReceiptResponse := TReceiptResponse.Create;
          Result := AReceiptResponse.ParseFromJSON(AResponse, Self);

         if Result then
         begin
             Log('ServiceCashOperation: Operation successful');

             // Оновлюємо баланс з відповіді сервера
             if Assigned(AReceiptResponse) and Assigned(AReceiptResponse.Shift) and
                      Assigned(AReceiptResponse.Shift.Balance) then
             begin
              FCurrentBalance := AReceiptResponse.Shift.Balance.Balance;
              Log('Баланс оновлено з відповіді: ' +
              FloatToStrF(FCurrentBalance / 100, ffNumber, 10, 2) + ' грн');
             end
             else
             begin
              // Резервний варіант - примусове оновлення
              FLastBalanceUpdate := 0;
              GetCurrentBalance(AResponse);
             end;
         end
        end;
      end
      else
      begin
        Log('ServiceCashOperation: CURL command failed: ' + AResponse);
      end;

    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('ServiceCashOperation: Exception: ' + E.Message);
      Result := False;
    end;
  end;
end;


function TReceiptWebAPI.ExtractBalanceFromShiftStatus(const JSONString: string): Integer;
var
  JsonParser: TJSONParser;
  JsonData, BalanceObj: TJSONObject;
begin
  Result := 0;
  try
    JsonParser := TJSONParser.Create(JSONString, [joUTF8]);
    try
      JsonData := JsonParser.Parse as TJSONObject;

      // Спроба №1: баланс в об'єкті balance
      if (JsonData.Find('balance') <> nil) and
         (JsonData.Items[JsonData.IndexOfName('balance')].JSONType = jtObject) then
      begin
        BalanceObj := JsonData.Objects['balance'];
        Result := BalanceObj.Get('balance', 0);
      end
      // Спроба №2: баланс в корені
      else if JsonData.Find('balance') <> nil then
      begin
        Result := JsonData.Get('balance', 0);
      end;

    finally
      JsonData.Free;
    end;
  except
    on E: Exception do
    begin
      Log('Помилка парсингу балансу: ' + E.Message);
      Result := 0;
    end;
  end;
end;

function TReceiptWebAPI.FormatBalanceInfo(Balance: TBalanceInfo): string;
begin
  if not Assigned(Balance) then
    Exit('Balance: N/A');

  Result := Format('💰 Баланс %.2f грн (Готівка: %.2f, Картка: %.2f, Знижки: %.2f, Націнки: %.2f)', [
    Balance.Balance / 100,
    Balance.CashSales / 100,
    Balance.CardSales / 100,
    Balance.DiscountsSum / 100,
    Balance.ExtraChargeSum / 100
  ]);
end;


function TReceiptWebAPI.ParseSignatureFromJSON(SignatureObj: TJSONObject): TSignature;
begin
  Result := TSignature.Create;
  try
    // Парсимо всі поля з перевіркою на наявність
    Result.SignatureType := SignatureObj.Get('signature_type', '');
    Result.Value := SignatureObj.Get('value', '');
    Result.SignatoryName := SignatureObj.Get('signatory_name', '');
    Result.SignatoryTin := SignatureObj.Get('signatory_tin', '');

    // Обробка дати з перевіркою
    if SignatureObj.Find('signed_at') <> nil then
      Result.SignedAt := ParseDateTime(SignatureObj.Get('signed_at', ''))
    else
      Result.SignedAt := 0;

    Result.Certificate := SignatureObj.Get('certificate', '');
    Result.CertificateThumbprint := SignatureObj.Get('certificate_thumbprint', '');
    Result.SignatureFormat := SignatureObj.Get('signature_format', '');
    Result.IsValid := SignatureObj.Get('is_valid', False);
    Result.ValidationDetails := SignatureObj.Get('validation_details', '');
    Result.RelatedDocumentId := SignatureObj.Get('related_document_id', '');
    Result.RelatedDocumentType := SignatureObj.Get('related_document_type', '');
  except
    on E: Exception do
    begin
      FreeAndNil(Result);
      raise; // Перекидаємо виняток далі
    end;
  end;
end;

function TReceiptResponse.ParseServiceOperationsFromJSON(ServiceArray: TJSONArray; AWebAPI: TReceiptWebAPI): Boolean;
var
  I: Integer;
  ServiceObj: TJSONObject;
  TempStr: string;
  TempDate: TDateTime;
begin
  Result := False;
  if not Assigned(ServiceArray) then
    Exit;

  try
    SetLength(ServiceOperations, ServiceArray.Count);
    for I := 0 to ServiceArray.Count - 1 do
    begin
      if ServiceArray.Items[I].JSONType = jtObject then
      begin
        ServiceObj := ServiceArray.Objects[I];
        if Assigned(ServiceObj) then
        begin
          ServiceOperations[I] := TServiceOperation.Create;
          // Парсимо кожне поле з перевіркою на наявність
          if ServiceObj.Find('id') <> nil
             then ServiceOperations[I].Id := ServiceObj.Get('id', '')
             else ServiceOperations[I].Id := '';
          if ServiceObj.Find('operation_type') <> nil
             then ServiceOperations[I].OperationType := ServiceObj.Get('operation_type', '')
             else ServiceOperations[I].OperationType := '';
          if ServiceObj.Find('amount') <> nil
             then ServiceOperations[I].Amount := ServiceObj.Get('amount', 0)
             else ServiceOperations[I].Amount := 0;
          if ServiceObj.Find('description') <> nil
             then ServiceOperations[I].Description := ServiceObj.Get('description', '')
             else ServiceOperations[I].Description := '';
          // Парсимо дати з перевіркою
          if ServiceObj.Find('created_at') <> nil then
          begin
            TempStr := ServiceObj.Get('created_at', '');
            TempDate := AWebAPI.ParseDateTime(TempStr);
            ServiceOperations[I].CreatedAt := TempDate;
          end
          else ServiceOperations[I].CreatedAt := 0;

          if ServiceObj.Find('updated_at') <> nil then
          begin
            TempStr := ServiceObj.Get('updated_at', '');
            TempDate := AWebAPI.ParseDateTime(TempStr);
            ServiceOperations[I].UpdatedAt := TempDate;
          end
          else ServiceOperations[I].UpdatedAt := 0;

          if ServiceObj.Find('transaction_id') <> nil then
            ServiceOperations[I].TransactionId := ServiceObj.Get('transaction_id', '')
          else ServiceOperations[I].TransactionId := '';

          if ServiceObj.Find('cashier_id') <> nil then
            ServiceOperations[I].CashierId := ServiceObj.Get('cashier_id', '')
          else ServiceOperations[I].CashierId := '';

          if ServiceObj.Find('shift_id') <> nil then
            ServiceOperations[I].ShiftId := ServiceObj.Get('shift_id', '')
          else ServiceOperations[I].ShiftId := '';

          if ServiceObj.Find('fiscal_number') <> nil then
            ServiceOperations[I].FiscalNumber := ServiceObj.Get('fiscal_number', '')
          else ServiceOperations[I].FiscalNumber := '';

          if ServiceObj.Find('document_number') <> nil then
            ServiceOperations[I].DocumentNumber := ServiceObj.Get('document_number', '')
          else ServiceOperations[I].DocumentNumber := '';

          if ServiceObj.Find('is_offline') <> nil then
            ServiceOperations[I].IsOffline := ServiceObj.Get('is_offline', False)
          else ServiceOperations[I].IsOffline := False;

          if ServiceObj.Find('offline_id') <> nil then
            ServiceOperations[I].OfflineId := ServiceObj.Get('offline_id', '')
          else ServiceOperations[I].OfflineId := '';
        end
        else
        begin
          // Якщо об'єкт не присвоєно, створюємо пустий об'єкт
          ServiceOperations[I] := TServiceOperation.Create;
        end;
      end
      else
      begin
        // Якщо елемент не об'єкт, створюємо пустий об'єкт
        ServiceOperations[I] := TServiceOperation.Create;
        AWebAPI.Log('ParseServiceOperationsFromJSON: Елемент service_operations[' + IntToStr(I) + '] не є об''єктом JSON');
      end;
    end;
    Result := True;

  except
    on E: Exception do
    begin
      AWebAPI.Log('ParseServiceOperationsFromJSON: Помилка парсингу службових операцій: ' + E.Message);
      Result := False;

      // У разі помилки звільняємо вже створені об'єкти
      for I := 0 to High(ServiceOperations) do
        if Assigned(ServiceOperations[I]) then
          FreeAndNil(ServiceOperations[I]);
      SetLength(ServiceOperations, 0);
    end;
  end;
end;

function TReceiptWebAPI.PinCodeLoginCurl(APinCode: string; out AResponse: string): Boolean;
var
  JsonData: TJSONObject;
  Command, JsonString, TempFile: string;
  StringList: TStringList;
begin
  Result := False;

  JsonData := nil;
  StringList := TStringList.Create;
  try
    // Формуємо JSON для авторизації за PIN-кодом згідно документації
    JsonData := TJSONObject.Create;
    try
      // Тільки PIN-код у тілі запиту
      JsonData.Add('pin_code', APinCode);

      JsonString := JsonData.AsJSON;
      Log('PinCodeLogin JSON: ' + JsonString);
    finally
      JsonData.Free;
    end;

    // Створюємо тимчасовий файл для JSON даних
    TempFile := GetTempDir + 'pin_login_' + GenerateUUID + '.json';
    StringList.Text := JsonString;
    StringList.SaveToFile(TempFile);

    try
      // Використовуємо правильний ендпоінт згідно документації
      Command := Format('-X POST ' +
                       '-H "accept: application/json" ' +
                       '-H "X-Client-Name: %s" ' +
                       '-H "X-Client-Version: %s" ' +
                       '-H "X-License-Key: %s" ' +
                       '-H "Content-Type: application/json" ' +
                       '--data-binary "@%s" ' +
                       '"%s/api/v1/cashier/signinPinCode"',
        [FClientName, FClientVersion, FLicenseKey, TempFile, FBaseURL]);

      Log('PinCodeLoginCurl: Виконуємо команду: curl ' + Command);

      // Виконуємо curl команду
      Result := ExecuteCurlCommand(Command, 'PinCodeLoginCurl', 'POST /api/v1/cashier/signinPinCode', AResponse);

      // Парсимо відповідь
      if Result then
      begin
        Log('PinCodeLoginCurl: Відповідь сервера: ' + Copy(AResponse, 1, 200));
        Result := ParsePinCodeAuthResponse(AResponse);
      end
      else
      begin
        Log('PinCodeLoginCurl: CURL command failed: ' + AResponse);
      end;

    finally
      // Видаляємо тимчасовий файл
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;
  finally
    StringList.Free;
  end;
end;

function TReceiptWebAPI.ParsePinCodeAuthResponse(const JSONString: string): Boolean;
var
  JsonData: TJSONObject;
  JsonParser: TJSONParser;
  ExpiresIn: Integer;
begin
  Result := False;

  // ✅ ДОДАНО: перевірка ініціалізації FAuthInfo
  if not Assigned(FAuthInfo) then
  begin
    Log('Помилка: FAuthInfo не ініціалізовано');
    Exit;
  end;

  JsonParser := TJSONParser.Create(JSONString, [joUTF8]);
  JsonData := nil;

  try
    try
      JsonData := JsonParser.Parse as TJSONObject;

      // Отримуємо всі поля з відповіді
      FAuthInfo.Token := JsonData.Get('access_token', '');
      FAuthInfo.TokenType := JsonData.Get('token_type', 'bearer');

      // Додаткове поле 'type' (якщо присутнє)
      if JsonData.Find('type') <> nil then
        FAuthInfo.TokenType := JsonData.Get('type', FAuthInfo.TokenType);

      // ✅ ВИПРАВЛЕНО: отримуємо ExpiresIn з JSON, а не фіксоване значення
      ExpiresIn := JsonData.Get('expires_in', 86400); // 24 години за замовчуванням

      // Для PIN-коду refresh_token зазвичай не надається
      FAuthInfo.RefreshToken := JsonData.Get('refresh_token', '');

      // ✅ ВИПРАВЛЕНО: коректне встановлення часу закінчення
      FAuthInfo.ExpiresAt := Now + (ExpiresIn / 86400); // Конвертація секунд в дні

      (*// ✅ ВИПРАВЛЕНО: синхронізація з зворотньою сумісністю (розкоментував)
      FAccessToken := FAuthInfo.Token;
      FTokenExpiration := FAuthInfo.ExpiresAt;*)

      Result := FAuthInfo.Token <> '';

      if Result then
      begin
        Log('PIN-код токен успішно отриманий. Expires: ' + DateTimeToStr(FAuthInfo.ExpiresAt));
        Log('Token type: ' + FAuthInfo.TokenType);
        Log('Expires in: ' + IntToStr(ExpiresIn) + ' секунд');
        // ✅ БЕЗПЕКА: логуємо тільки початок токена
        Log('Token (first 20 chars): ' + Copy(FAuthInfo.Token, 1, 20) + '...');
      end
      else
      begin
        Log('Не вдалося отримати токен з відповіді');
        Log('JSON response: ' + Copy(JSONString, 1, 200) + '...');
      end;

    except
      on E: Exception do
      begin
        Log('Exception in ParsePinCodeAuthResponse: ' + E.Message);
        Log('JSON that caused error: ' + Copy(JSONString, 1, 200));
        Result := False;
      end;
    end;

  finally
    // ✅ ВИПРАВЛЕНО: правильний порядок звільнення пам'яті
    if Assigned(JsonData) then
      JsonData.Free;
    JsonParser.Free;
  end;
end;

(*function TReceiptWebAPI.ValidateAPIState: Boolean;
begin
  Result := (FAccessToken <> '') and (FTokenExpiration > Now);
  if not Result then
    Log('ValidateAPIState: Токен недійсний (FAccessToken=' + FAccessToken +
        ', FTokenExpiration=' + DateTimeToStr(FTokenExpiration) + ')');

    Result := Assigned(FAuthInfo) and
           (FAuthInfo.Token <> '') and
           (FAuthInfo.ExpiresAt > Now);
end;*)

function TReceiptWebAPI.GetAuthToken: string;
begin
  if Assigned(FAuthInfo) then
    Result := FAuthInfo.Token
  else
    Result := '';
end;

procedure TReceiptWebAPI.SetAuthToken(const Value: string);
begin
  if not Assigned(FAuthInfo) then
    FAuthInfo := TAuthInfo.Create;
  FAuthInfo.Token := Value;
end;


function TReceiptWebAPI.ReceiptTypeToString(AReceiptType: TReceiptType): string;
begin
  case AReceiptType of
    rtSell: Result := 'SELL';
    rtReturn: Result := 'RETURN';
    rtServiceIn: Result := 'SERVICE_IN';
    rtServiceOut: Result := 'SERVICE_OUT';
    rtCashWithdrawal: Result := 'CASH_WITHDRAWAL';
  else
    Result := 'SELL';
  end;
end;

function TReceiptWebAPI.StringToReceiptType(const ATypeStr: string): TReceiptType;
begin
  if ATypeStr = 'SELL' then
    Result := rtSell
  else if ATypeStr = 'RETURN' then
    Result := rtReturn
  else if ATypeStr = 'SERVICE_IN' then
    Result := rtServiceIn
  else if ATypeStr = 'SERVICE_OUT' then
    Result := rtServiceOut
  else if ATypeStr = 'CASH_WITHDRAWAL' then
    Result := rtCashWithdrawal
  else
    Result := rtSell;
end;


// Додати нові функції для роботи з податками
function TReceiptWebAPI.CreateTaxByGroup(const ATaxGroup: string): TTax;
begin
  Result := TTax.Create;
  Result.Id := GenerateUUID;

  // Відповідність груп податків кодам з API Checkbox
  if ATaxGroup = 'VAT20' then
  begin
    Result.Code := 1;
    Result.Rate := 20.0;
    Result.LabelText := 'ПДВ 20%';
    Result.Symbol := '🟥';
  end
  else if ATaxGroup = 'VAT7' then
  begin
    Result.Code := 2;
    Result.Rate := 7.0;
    Result.LabelText := 'ПДВ 7%';
    Result.Symbol := '🟨';
  end
  else if ATaxGroup = 'VAT0' then
  begin
    Result.Code := 3;
    Result.Rate := 0.0;
    Result.LabelText := 'ПДВ 0%';
    Result.Symbol := '🟩';
  end
  else if ATaxGroup = 'NO_VAT' then
  begin
    Result.Code := 4;
    Result.Rate := 0.0;
    Result.LabelText := 'Звільнено від ПДВ';
    Result.Symbol := '⬜';
  end
  else
  begin
    // За замовчуванням
     Result.Code := 3;
    Result.Rate := 0.0;
    Result.LabelText := 'ПДВ 0%';
    Result.Symbol := '🟩';
  end;
end;

function TReceiptWebAPI.CalculateTaxValue(APrice: Integer; ATaxRate: Double): Double;
begin
  // Розрахунок суми податку в копійках
  Result := (APrice * ATaxRate) / (100 + ATaxRate);
end;

(*function TReceiptWebAPI.ValidateReceiptStructure(AReceipt: TReceipt; out AError: string): Boolean;
var
  I: Integer;
  TotalGoodsSum, TotalPaymentsSum: Integer;
begin
  Result := False;

  // Перевірка базових полів
  if AReceipt.Id = '' then
  begin
    AError := 'Відсутній ID чека';
    Exit;
  end;

  if not IsValidUUID(AReceipt.Id) then
  begin
    AError := 'Невірний формат UUID';
    Exit;
  end;

  if AReceipt.CashierName = '' then
  begin
    AError := 'Відсутнє ім''я касира';
    Exit;
  end;

  // Перевірка товарів
  if Length(AReceipt.Goods) = 0 then
  begin
    AError := 'Чек повинен містити хоча б один товар';
    Exit;
  end;

  TotalGoodsSum := 0;
  for I := 0 to High(AReceipt.Goods) do
  begin
    if AReceipt.Goods[I].Good.Code = '' then
    begin
      AError := Format('Товар %d: відсутній код', [I+1]);
      Exit;
    end;

    if AReceipt.Goods[I].Good.Price <= 0 then
    begin
      AError := Format('Товар %s: некоректна ціна', [AReceipt.Goods[I].Good.Code]);
      Exit;
    end;

    if AReceipt.Goods[I].Quantity <= 0 then
    begin
      AError := Format('Товар %s: некоректна кількість', [AReceipt.Goods[I].Good.Code]);
      Exit;
    end;

    // Розрахунок загальної суми товарів
    TotalGoodsSum := TotalGoodsSum + AReceipt.Goods[I].Sum;
  end;

  // Перевірка оплат
  if Length(AReceipt.Payments) = 0 then
  begin
    AError := 'Відсутні оплати';
    Exit;
  end;

  TotalPaymentsSum := 0;
  for I := 0 to High(AReceipt.Payments) do
  begin
    if AReceipt.Payments[I].Value <= 0 then
    begin
      AError := Format('Оплата %d: некоректна сума', [I+1]);
      Exit;
    end;
    TotalPaymentsSum := TotalPaymentsSum + AReceipt.Payments[I].Value;
  end;

  // Перевірка співпадіння сум
  if Abs(TotalGoodsSum - AReceipt.TotalSum) > 1 then // Допуск 1 копійка
  begin
    AError := Format('Неспівпадіння сум: товари=%d, total_sum=%d',
      [TotalGoodsSum, AReceipt.TotalSum]);
    Exit;
  end;

  // Перевірка решти
  if AReceipt.TotalPayment < AReceipt.TotalSum then
  begin
    AError := 'Недостатня сума оплати';
    Exit;
  end;

  if AReceipt.Rest <> (AReceipt.TotalPayment - AReceipt.TotalSum) then
  begin
    AError := 'Некоректний розрахунок решти';
    Exit;
  end;

  Result := True;
end; *)

function TReceiptWebAPI.ValidateReceiptStructure(AReceipt: TReceipt; out AError: string): Boolean;
var
  I, J, TotalPayment, TotalGoodsSum: Integer;
  Good: TGoodItem;
  Payment: TPayment;
begin
  Result := False;
  AError := '';

  // Базові перевірки наявності об'єкта
  if not Assigned(AReceipt) then
  begin
    AError := 'Чек не ініціалізовано';
    Exit;
  end;

  // Перевірка обов'язкових полів
  if AReceipt.Id = '' then
  begin
    AError := 'ID чека є обовʼязковим полем';
    Exit;
  end;

  if not IsValidUUID(AReceipt.Id) then
  begin
    AError := 'ID чека має бути у форматі UUID v4';
    Exit;
  end;

  if AReceipt.CashierName = '' then
  begin
    AError := 'Імʼя касира є обовʼязковим полем';
    Exit;
  end;

  if AReceipt.Departament = '' then
  begin
    AError := 'Відділ є обовʼязковим полем';
    Exit;
  end;

  // Перевірка товарів
  if Length(AReceipt.Goods) = 0 then
  begin
    AError := 'Чек повинен містити хоча б один товар';
    Exit;
  end;

  TotalGoodsSum := 0;
  for I := 0 to High(AReceipt.Goods) do
  begin
    Good := AReceipt.Goods[I];
    if not Assigned(Good) then
    begin
      AError := Format('Товар #%d не ініціалізовано', [I + 1]);
      Exit;
    end;

    if not Assigned(Good.Good) then
    begin
      AError := Format('Обʼєкт товару #%d не ініціалізовано', [I + 1]);
      Exit;
    end;

    // Перевірка обов'язкових полей товару
    if Good.Good.Code = '' then
    begin
      AError := Format('Код товару #%d є обовʼязковим', [I + 1]);
      Exit;
    end;

    if Good.Good.Name = '' then
    begin
      AError := Format('Назва товару #%d є обовʼязковою', [I + 1]);
      Exit;
    end;

    if Good.Good.Price <= 0 then
    begin
      AError := Format('Ціна товару #%d повинна бути більше 0', [I + 1]);
      Exit;
    end;

    if Good.Quantity <= 0 then
    begin
      AError := Format('Кількість товару #%d повинна бути більше 0', [I + 1]);
      Exit;
    end;

    if Good.Sum <= 0 then
    begin
      AError := Format('Сума товару #%d повинна бути більше 0', [I + 1]);
      Exit;
    end;

    // Перевірка узгодженості ціни та кількості
    if Good.Sum <> (Good.Good.Price * Good.Quantity) div 1000 then
    begin
      AError := Format('Неузгодженість ціни та кількості для товару #%d', [I + 1]);
      Exit;
    end;

    // Додаємо до загальної суми товарів
    TotalGoodsSum := TotalGoodsSum + Good.Sum;
  end;

  // Перевірка платежів
  if Length(AReceipt.Payments) = 0 then
  begin
    AError := 'Чек повинен містити хоча б один платіж';
    Exit;
  end;

  TotalPayment := 0;
  for I := 0 to High(AReceipt.Payments) do
  begin
    Payment := AReceipt.Payments[I];
    if not Assigned(Payment) then
    begin
      AError := Format('Платіж #%d не ініціалізовано', [I + 1]);
      Exit;
    end;

    if Payment.Value <= 0 then
    begin
      AError := Format('Сума платежу #%d повинна бути більше 0', [I + 1]);
      Exit;
    end;

    // Перевірка типів оплати
    case Payment.PaymentType of
      ptCash, ptCashless, ptCard:
        begin
          // Валідні типи
        end;
    else
      AError := Format('Невідомий тип оплати для платежу #%d', [I + 1]);
      Exit;
    end;

    // Специфічні перевірки для карткових платежів
    if Payment.PaymentType = ptCard then
    begin
      if Payment.ProviderType = '' then
      begin
        AError := Format('Для карткових платежів обовʼязково вказувати ProviderType (платіж #%d)', [I + 1]);
        Exit;
      end;

      // Перевірка валідності провайдера
      if (Payment.ProviderType <> 'BANK') and
         (Payment.ProviderType <> 'TAPXPHONE') and
         (Payment.ProviderType <> 'POSCONTROL') and
         (Payment.ProviderType <> 'TERMINAL') then
      begin
        AError := Format('Невідомий провайдер оплати: %s (платіж #%d)',
          [Payment.ProviderType, I + 1]);
        Exit;
      end;
    end;

    // Перевірка міток оплати
    if Payment.LabelText = '' then
    begin
      case Payment.PaymentType of
        ptCash: Payment.LabelText := 'Готівка';
        ptCashless: Payment.LabelText := 'Безготівковий розрахунок';
        ptCard: Payment.LabelText := 'Банківська картка';
      end;
    end;

    // Додаємо до загальної суми платежів
    TotalPayment := TotalPayment + Payment.Value;
  end;

  // Перевірка відповідності сум товарів та платежів
  if TotalGoodsSum <> AReceipt.TotalSum then
  begin
    AError := Format('Сума товарів (%d) не відповідає загальній сумі чека (%d)',
      [TotalGoodsSum, AReceipt.TotalSum]);
    Exit;
  end;

  if TotalPayment <> AReceipt.TotalPayment then
  begin
    AError := Format('Сума платежів (%d) не відповідає загальній оплаті (%d)',
      [TotalPayment, AReceipt.TotalPayment]);
    Exit;
  end;

  if AReceipt.TotalSum <> AReceipt.TotalPayment then
  begin
    AError := Format('Загальна сума (%d) не відповідає загальній оплаті (%d)',
      [AReceipt.TotalSum, AReceipt.TotalPayment]);
    Exit;
  end;

  // Перевірка знижок
  for I := 0 to High(AReceipt.Discounts) do
  begin
    if Assigned(AReceipt.Discounts[I]) then
    begin
      if AReceipt.Discounts[I].Value <= 0 then
      begin
        AError := Format('Значення знижки #%d повинно бути більше 0', [I + 1]);
        Exit;
      end;

      if AReceipt.Discounts[I].Sum <= 0 then
      begin
        AError := Format('Сума знижки #%d повинна бути більше 0', [I + 1]);
        Exit;
      end;
    end;
  end;

  // Перевірка бонусів
  for I := 0 to High(AReceipt.Bonuses) do
  begin
    if Assigned(AReceipt.Bonuses[I]) then
    begin
      if AReceipt.Bonuses[I].BonusCard = '' then
      begin
        AError := Format('Бонусна карта #%d повинна мати номер', [I + 1]);
        Exit;
      end;

      if AReceipt.Bonuses[I].Value <= 0 then
      begin
        AError := Format('Значення бонусу #%d повинно бути більше 0', [I + 1]);
        Exit;
      end;
    end;
  end;

  // Перевірка податків
  for I := 0 to High(AReceipt.Taxes) do
  begin
    if Assigned(AReceipt.Taxes[I]) then
    begin
      if AReceipt.Taxes[I].Code <= 0 then
      begin
        AError := Format('Код податку #%d повинен бути більше 0', [I + 1]);
        Exit;
      end;

      if AReceipt.Taxes[I].Rate < 0 then
      begin
        AError := Format('Ставка податку #%d не може бути відʼємною', [I + 1]);
        Exit;
      end;
    end;
  end;

  // Перевірка службових операцій
  for I := 0 to High(AReceipt.ServiceOperations) do
  begin
    if Assigned(AReceipt.ServiceOperations[I]) then
    begin
      if AReceipt.ServiceOperations[I].OperationType = '' then
      begin
        AError := Format('Тип службової операції #%d є обовʼязковим', [I + 1]);
        Exit;
      end;

      if AReceipt.ServiceOperations[I].Amount <= 0 then
      begin
        AError := Format('Сума службової операції #%d повинна бути більше 0', [I + 1]);
        Exit;
      end;
    end;
  end;

  // Перевірка підписів
  for I := 0 to High(AReceipt.Signatures) do
  begin
    if Assigned(AReceipt.Signatures[I]) then
    begin
      if AReceipt.Signatures[I].SignatureType = '' then
      begin
        AError := Format('Тип підпису #%d є обовʼязковим', [I + 1]);
        Exit;
      end;

      if AReceipt.Signatures[I].Value = '' then
      begin
        AError := Format('Значення підпису #%d є обовʼязковим', [I + 1]);
        Exit;
      end;
    end;
  end;

  // Додаткова перевірка для офлайн-режиму
  if AReceipt.IsOffline then
  begin
    if AReceipt.OfflineSequenceNumber <= 0 then
    begin
      AError := 'Для офлайн-чека обовʼязковий OfflineSequenceNumber > 0';
      Exit;
    end;
  end;

  Result := True;
  Log('Валідація чека пройдена успішно: ' + AReceipt.Id);
end;

function TReceiptWebAPI.IsNetworkError(const AResponse: string): Boolean;
begin
  // Перевіряємо типові ознаки мережевої помилки
  Result := (Pos('Connection refused', AResponse) > 0) or
            (Pos('Could not resolve host', AResponse) > 0) or
            (Pos('Operation timed out', AResponse) > 0) or
            (Pos('Network is unreachable', AResponse) > 0) or
            (Pos('No route to host', AResponse) > 0) or
            (Pos('SSL connection error', AResponse) > 0);
end;



procedure TReceiptWebAPI.HandleAuthState(Action: TAuthAction);
var
  IniFile: TIniFile;
  ConfigDir: string;
begin
  if not Assigned(FAuthInfo) then
  begin
    if Action <> aaClear then  // Для очищення дозволяємо, навіть якщо не ініціалізовано
      Exit;
    FAuthInfo := TAuthInfo.Create;  // Ініціалізуємо, якщо потрібно
  end;

  ConfigDir := GetAppConfigDir(False);
  ForceDirectories(ConfigDir);  // Забезпечуємо існування директорії
  IniFile := TIniFile.Create(ConfigDir + 'auth_state.ini');

  try
    try
      case Action of
        aaSave:  // Збереження (заміняє SaveAuthToFile)
        begin
          if FAuthInfo.Token <> '' then
          begin
            IniFile.WriteString('Auth', 'Token', FAuthInfo.Token);
            IniFile.WriteString('Auth', 'TokenType', FAuthInfo.TokenType);
            IniFile.WriteString('Auth', 'RefreshToken', FAuthInfo.RefreshToken);
            IniFile.WriteDateTime('Auth', 'ExpiresAt', FAuthInfo.ExpiresAt);
            IniFile.WriteDateTime('Auth', 'LastUpdate', Now);
            Log('Авторизацію збережено в файл auth_state.ini');
          end
          else
            Log('Нічого зберігати: токен порожній');
        end;

        aaClear:  // Очищення (нова, аналогічно ClearShiftState)
        begin
          FAuthInfo.Token := '';
          FAuthInfo.TokenType := '';
          FAuthInfo.RefreshToken := '';
          FAuthInfo.ExpiresAt := 0;
          IniFile.EraseSection('Auth');
          IniFile.UpdateFile;
          Log('Стан авторизації очищено (токен та файл)');
        end;

        aaLoad:  // Завантаження (заміняє LoadAuthFromFile)
        begin
          if IniFile.SectionExists('Auth') then
          begin
            FAuthInfo.Token := IniFile.ReadString('Auth', 'Token', '');
            FAuthInfo.TokenType := IniFile.ReadString('Auth', 'TokenType', 'bearer');
            FAuthInfo.RefreshToken := IniFile.ReadString('Auth', 'RefreshToken', '');
            FAuthInfo.ExpiresAt := IniFile.ReadDateTime('Auth', 'ExpiresAt', 0);

            if (FAuthInfo.Token <> '') and (FAuthInfo.ExpiresAt > Now) then
              Log('Авторизацію завантажено з файлу. Дійсна до: ' + DateTimeToStr(FAuthInfo.ExpiresAt))
            else
            begin
              Log('Збережена авторизація недійсна - очищення файлу');
              IniFile.EraseSection('Auth');
              IniFile.UpdateFile;
              FAuthInfo.Token := '';
              FAuthInfo.ExpiresAt := 0;
            end;
          end
          else
            Log('Файл авторизації порожній або відсутній');
        end;
      end;
    except
      on E: Exception do
        Log('Помилка в HandleAuthState (' + GetEnumName(TypeInfo(TAuthAction), Ord(Action)) + '): ' + E.Message);
    end;
  finally
    IniFile.Free;
  end;
end;

function TReceiptWebAPI.GetCurrentCashierInfo(var Response: string): Boolean;
var
  Command, Url: string;
  TempResponse: string;
begin
   // -----  НЕ ПРАЦЮЄ  !!!!!-------------


(*  Result := False;
  Response := '';

  // Перевірка валідності токена
  if not IsTokenValid then
  begin
    Response := 'Токен недійсний';
    Log('Помилка: Токен недійсний для отримання інформації про касира');
    Exit;
  end;

  // Перевірка заповненості обов'язкових полів
  if (FAuthInfo.Token = '') or (FClientName = '') or (FClientVersion = '') then
  begin
    Response := 'Відсутні обовʼязкові дані для запиту (токен, клієнт, версія)';
    Log('Помилка: Недостатньо даних для формування запиту');
    Exit;
  end;

  try
    // Використовуємо правильний ендпоінт з документації
    Url := FBaseURL + '/api/v1/cashiers/me';
    Log('[GetCurrentCashierInfo] GET ' + Url);

    // Формуємо curl команду з усіма необхідними заголовками
    Command := Format(
      'curl -s -X GET ' +
      '-H "Accept: application/json" ' +
      '-H "Authorization: Bearer %s" ' +
      '-H "X-Client-Name: %s" ' +
      '-H "X-Client-Version: %s" ' +
      '"%s"',
      [FAuthInfo.Token, FClientName, FClientVersion, Url]
    );

    Log('Виконуємо curl команду для отримання інформації про касира');

    // Виконуємо команду через допоміжну функцію
    TempResponse := '';
    if not ExecuteCurlCommand(Command, 'GetCurrentCashierInfo', 'GET /api/v1/cashiers/me', TempResponse) then
    begin
      Response := 'Помилка виконання curl команди';
      Log('Помилка: Не вдалося виконати curl команду для отримання інформації касира');
      Exit;
    end;

    Response := TempResponse;

    // Перевіряємо наявність помилок у відповіді
    if Response = '' then
    begin
      Log('Помилка: Порожня відповідь від сервера');
      Response := 'Порожня відповідь від сервера';
      Exit;
    end;

    // Аналізуємо відповідь на наявність помилок API
    if Pos('"message"', Response) > 0 then
    begin
      if Pos('"Not Found"', Response) > 0 then
      begin
        Log('Помилка: Ендпоінт не знайдено (404). Можливо, некоректний URL або права доступу');
        Response := 'Ендпоінт не знайдено. Перевірте URL та права доступу';
        Exit;
      end
      else if Pos('"Unauthorized"', Response) > 0 then
      begin
        Log('Помилка: Неавторизований доступ (401). Токен може бути недійсним');
        Response := 'Неавторизований доступ. Перевірте токен';
        Exit;
      end
      else if Pos('"Forbidden"', Response) > 0 then
      begin
        Log('Помилка: Доступ заборонено (403). Недостатньо прав');
        Response := 'Доступ заборонено. Недостатньо прав для отримання інформації касира';
        Exit;
      end
      else if Pos('"Internal Server Error"', Response) > 0 then
      begin
        Log('Помилка: Внутрішня помилка сервера (500)');
        Response := 'Внутрішня помилка сервера Checkbox API';
        Exit;
      end
      else if Pos('"Bad Request"', Response) > 0 then
      begin
        Log('Помилка: Невірний запит (400)');
        Response := 'Невірний запит до Checkbox API';
        Exit;
      end;
    end;

    // Перевіряємо успішність відповіді за наявністю ID касира
    Result := (Pos('"id"', Response) > 0) or (Pos('"cashier_id"', Response) > 0);

    if Result then
    begin
      Log('Інформацію про касира отримано успішно');

      // Додаткова інформація для логування
      if Pos('"name"', Response) > 0 then
        Log('Знайдено ім''я касира у відповіді')
      else if Pos('"full_name"', Response) > 0 then
        Log('Знайдено повне ім''я касира у відповіді');

      if Pos('"email"', Response) > 0 then
        Log('Знайдено email касира у відповіді');

      Log('Перші 200 символів відповіді: ' + Copy(Response, 1, 200) + '...');
    end
    else
    begin
      Log('Помилка: Відповідь не містить очікуваних даних касира');
      Log('Повна відповідь: ' + Copy(Response, 1, 500));

      // Додаткова інформація для відладки
      if Pos('error', LowerCase(Response)) > 0 then
        Log('Відповідь містить помилку API')
      else if Pos('success', LowerCase(Response)) > 0 then
        Log('Відповідь містить ознаки успіху, але не знайдено ID касира');
    end;

  except
    on E: Exception do
    begin
      Response := 'Виняток при отриманні інформації касира: ' + E.Message;
      Log('Критичний виняток в GetCurrentCashierInfo: ' + E.Message + ' | Клас: ' + E.ClassName);
      Result := False;
    end;
  end; *)
end;

function TReceiptWebAPI.CreateCardPayment(AValue: Integer;
  AProvider: TPaymentProvider; ACardMask, AAuthCode, ARRN: string): TPayment;
begin
  Result := TPayment.Create;
  Result.PaymentType := ptCard;
  Result.Value := AValue;
  Result.ProviderType := PaymentProviderToString(AProvider);
  Result.LabelText := 'Банківська картка';
  Result.Code := 2; // Код для безготівкових оплат
  Result.CardMask := ACardMask;
  Result.AuthCode := AAuthCode;
  Result.RRN := ARRN;
end;

function TReceiptWebAPI.GetReportText(const AReportId: string; out AResponse: string): Boolean;
var
  Command: string;
begin
  Result := False;
  AResponse := '';

  if not IsTokenValid then
  begin
    if not LoginCurl(FUsername, FPassword, AResponse) then
    begin
      Log('Потрібен повторний вхід: ' + AResponse);
      Exit;
    end;
  end;

  try
    Command := Format('-X GET -H "Accept: text/plain" -H "X-Client-Name: %s" ' +
                     '-H "X-Client-Version: %s" -H "Authorization: Bearer %s" ' +
                     '"%s/api/v1/reports/%s/txt"',
      [FClientName, FClientVersion, FAuthInfo.Token, FBaseURL, AReportId]);

    Result := ExecuteCurlCommand(Command, 'GetReportText', 'GET /api/v1/reports/ReportID/txt', AResponse);

  except
    on E: Exception do
    begin
      AResponse := 'CURL command error: ' + E.Message;
      Log('GetReportText: Виняток: ' + E.Message);
      Result := False;
    end;
  end;
end;





function TReceiptWebAPI.GetReceiptHTML(const AReceiptId: string; out AHTMLContent: string): Boolean;
var
  LCommand: string;
  LOutputFile: string;
  LFile: TStringList;
  LResponse: string;
begin
  Result := False;
  AHTMLContent := '';

  LOutputFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'receipt_' + AReceiptId + '_' + IntToStr(GetTickCount) + '.html';

  // Формуємо curl команду для Linux
  LCommand := '-X ''GET'' ' +
              '''https://api.checkbox.ua/api/v1/receipts/' + AReceiptId + '/html'' ' +
              '-H ''accept: text/html'' ' +
              '-H ''X-Client-Name: ' + FClientName + ''' ' +
              '-H ''X-Client-Version: ' + FClientVersion + ''' ' +
              '-o "' + LOutputFile + '"';

  try
    if ExecuteCurlCommand(LCommand, 'GetReceiptHTML', '/receipts/' + AReceiptId + '/html', LResponse) then
    begin
      // Читаємо отриманий HTML файл
      if FileExists(LOutputFile) then
      begin
        LFile := TStringList.Create;
        try
          LFile.LoadFromFile(LOutputFile);
          AHTMLContent := LFile.Text;
          Result := True;
        finally
          LFile.Free;
        end;
        DeleteFile(LOutputFile); // Видаляємо тимчасовий файл
      end;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Помилка отримання HTML: ' + E.Message;
    end;
  end;
end;

function TReceiptWebAPI.GetReceiptPNG(const AReceiptId: string; out AFileName: string;
  const AWidth: Integer = 0; const APaperWidth: Integer = 0;
  const AQRCodeScale: Integer = 0): Boolean;
var
  LCommand: string;
  LParams: string;
  LResponse: string;
begin
  Result := False;
  AFileName := '';

  // Формуємо параметри
  LParams := '';
  if AWidth > 0 then
    LParams := LParams + 'width=' + IntToStr(AWidth);
  if APaperWidth > 0 then
  begin
    if LParams <> '' then LParams := LParams + '&';
    LParams := LParams + 'paper_width=' + IntToStr(APaperWidth);
  end;
  if AQRCodeScale > 0 then
  begin
    if LParams <> '' then LParams := LParams + '&';
    LParams := LParams + 'qrcode_scale=' + IntToStr(AQRCodeScale);
  end;

  // Створюємо унікальне ім'я файлу для Linux
  AFileName := IncludeTrailingPathDelimiter(FReceiptsDirectory) + 'receipt_' + AReceiptId + '_' + IntToStr(GetTickCount) + '.png';

  // Формуємо curl команду для Linux
  LCommand := '-X ''GET'' ' +
              '''https://api.checkbox.ua/api/v1/receipts/' + AReceiptId + '/png';
  if LParams <> '' then
    LCommand := LCommand + '?' + LParams;
  LCommand := LCommand + ''' ' +
              '-H ''accept: image/png'' ' +
              '-H ''X-Client-Name: ' + FClientName + ''' ' +
              '-H ''X-Client-Version: ' + FClientVersion + ''' ' +
              '--output "' + AFileName + '"';

  try
    Result := ExecuteCurlCommand(LCommand, 'GetReceiptPNG', '/receipts/' + AReceiptId + '/png', LResponse);
    if Result then
    begin
      if not FileExists(AFileName) then
      begin
        Result := False;
        FLastError := 'Файл PNG не було створено';
      end;
    end
    else
    begin
      FLastError := 'Помилка виконання curl: ' + LResponse;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Помилка отримання PNG: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TReceiptWebAPI.GetReceiptText(const AReceiptId: string; out ATextContent: string): Boolean;
var
  LCommand: string;
  LOutputFile: string;
  LFile: TStringList;
  LResponse: string;
begin
  Result := False;
  ATextContent := '';

  LOutputFile := IncludeTrailingPathDelimiter(FTempDirectory) + 'receipt_' + AReceiptId + '_' + IntToStr(GetTickCount) + '.txt';

  // Формуємо curl команду для Linux
  LCommand := '-X ''GET'' ' +
              '''https://api.checkbox.ua/api/v1/receipts/' + AReceiptId + '/text'' ' +
              '-H ''accept: text/plain'' ' +
              '-H ''X-Client-Name: ' + FClientName + ''' ' +
              '-H ''X-Client-Version: ' + FClientVersion + ''' ' +
              '-o "' + LOutputFile + '"';

  try
    if ExecuteCurlCommand(LCommand, 'GetReceiptText', '/receipts/' + AReceiptId + '/text', LResponse) then
    begin
      // Читаємо отриманий текстовий файл
      if FileExists(LOutputFile) then
      begin
        LFile := TStringList.Create;
        try
          LFile.LoadFromFile(LOutputFile);
          ATextContent := LFile.Text;
          Result := True;
        finally
          LFile.Free;
        end;
        DeleteFile(LOutputFile); // Видаляємо тимчасовий файл
      end;
    end
    else
    begin
      FLastError := 'Помилка виконання curl: ' + LResponse;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Помилка отримання тексту: ' + E.Message;
    end;
  end;
end;

function TReceiptWebAPI.GetReceiptQRCode(const AReceiptId: string; out AFileName: string): Boolean;
var
  LCommand: string;
  LResponse: string;
begin
  Result := False;
  AFileName := '';

  // Створюємо унікальне ім'я файлу для Linux
  AFileName := IncludeTrailingPathDelimiter(FReceiptsDirectory) + 'receipt_' + AReceiptId + '_qrcode_' + IntToStr(GetTickCount) + '.png';

  // Формуємо curl команду для Linux
  LCommand := '-X ''GET'' ' +
              '''https://api.checkbox.ua/api/v1/receipts/' + AReceiptId + '/qrcode'' ' +
              '-H ''accept: image/png'' ' +
              '-H ''X-Client-Name: ' + FClientName + ''' ' +
              '-H ''X-Client-Version: ' + FClientVersion + ''' ' +
              '-o "' + AFileName + '"';

  try
    Result := ExecuteCurlCommand(LCommand, 'GetReceiptQRCode', '/receipts/' + AReceiptId + '/qrcode', LResponse);
    if Result then
    begin
      if not FileExists(AFileName) then
      begin
        Result := False;
        FLastError := 'Файл QR-коду не було створено';
      end;
    end
    else
    begin
      FLastError := 'Помилка виконання curl: ' + LResponse;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Помилка отримання QR-коду: ' + E.Message;
      Result := False;
    end;
  end;
end;




end.

