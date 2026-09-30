unit ChekTypes;

interface

uses
  SysUtils;

{═══════════════════════════════════════════════════════════════════════════════}
{  РІВЕНЬ 1: ТИПИ ОПЛАТИ (PAYMENT TYPES)                                        }
{═══════════════════════════════════════════════════════════════════════════════}

type
  TPaymentTypeUI = (
    ptuCash,      // Готівка
    ptuCashless,  // Безготівковий
    ptuMixed,     // Змішана
    ptuOther      // Інше
  );

  TPaymentTypeAPI = (
    ptaCash,      // CASH
    ptaCashless,  // CASHLESS
    ptaMixed,     // MIXED
    ptaOther      // OTHER
  );

  TPaymentTypeCode = 1..4;



const
  PaymentTypeUI_Names: array[TPaymentTypeUI] of string = (
    'Готівка',        // ptuCash
    'Безготівковий',  // ptuCashless
    'Змішана',        // ptuMixed
    'Інше'            // ptuOther
  );

  PaymentTypeAPI_Codes: array[TPaymentTypeAPI] of string = (
    'CASH',      // ptaCash
    'CASHLESS',  // ptaCashless
    'MIXED',     // ptaMixed
    'OTHER'      // ptaOther
  );

  PaymentType_Numbers: array[TPaymentTypeUI] of Integer = (
    1,  // ptuCash
    2,  // ptuCashless
    3,  // ptuMixed
    4   // ptuOther
  );

{═══════════════════════════════════════════════════════════════════════════════}
{  РІВЕНЬ 2: ПІДТИПИ БЕЗГОТІВКОВОЇ ОПЛАТИ (CASHLESS SUBTYPES)                  }
{═══════════════════════════════════════════════════════════════════════════════}

type
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
  CashlessSubTypeUI_Names: array[1..17] of string = (
    'Картка',                          // 1  cstCard
    'Інтернет банкінг',                // 2  cstInternetBanking
    'Інтернет еквайринг',              // 3  cstInternetAcquiring
    'Платіж через інтегратора LiqPay', // 4  cstLiqPay
    'Платіж через інтегратора mono',   // 5  cstMono  ← з малої літери
    'Платіж через інтегратора WayForPay', // 6 cstWayForPay
    'Платіж через NovaPay',            // 7  cstNovaPay
    'Платіж через інтегратора EasyPay',// 8  cstEasyPay
    'Подарунковий сертифікат',         // 9  cstGiftCertificate
    'Талон',                           // 10 cstToken
    'Переказ ННПП',                    // 11 cstTransferNNPP
    'Переказ ПТКС',                    // 12 cstTransferPTKS
    'З поточного рахунку',             // 13 cstCurrentAccount
    'Електронні гроші',                // 14 cstElectronicMoney
    'Цифрові гроші',                   // 15 cstDigitalMoney
    'Криптовалюта',                    // 16 cstCryptocurrency
    'Інше безготівкове'                // 17 cstOtherCashless
  );

  CashlessSubTypeAPI_Codes: array[1..17] of string = (
    'Card',              // 1  cstCard
    'InternetBanking',   // 2  cstInternetBanking
    'InternetAcquiring', // 3  cstInternetAcquiring
    'LiqPay',            // 4  cstLiqPay
    'Mono',              // 5  cstMono
    'WayForPay',         // 6  cstWayForPay
    'NovaPay',           // 7  cstNovaPay
    'EasyPay',           // 8  cstEasyPay
    'GiftCertificate',   // 9  cstGiftCertificate
    'Token',             // 10 cstToken
    'TransferNNPP',      // 11 cstTransferNNPP
    'TransferPTKS',      // 12 cstTransferPTKS
    'CurrentAccount',    // 13 cstCurrentAccount
    'ElectronicMoney',   // 14 cstElectronicMoney
    'DigitalMoney',      // 15 cstDigitalMoney
    'Cryptocurrency',    // 16 cstCryptocurrency
    'OtherCashless'      // 17 cstOtherCashless
  );

{═══════════════════════════════════════════════════════════════════════════════}
{  РІВЕНЬ 3: ПРОВАЙДЕРИ КАРТКОВИХ ПЛАТЕЖІВ (CARD PROVIDERS)                    }
{═══════════════════════════════════════════════════════════════════════════════}

const
  CardProviders: array[0..3] of string = (
    'BANK',        // Банківський термінал
    'TAPXPHONE',   // TapXPhone (смартфон як термінал)
    'POSCONTROL',  // POS-контроль
    'TERMINAL'     // Загальний термінал
  );

  CardProviderUI_Names: array[0..3] of string = (
    'Банк',        // BANK
    'TapXPhone',   // TAPXPHONE
    'POS-контроль',// POSCONTROL
    'Термінал'     // TERMINAL
  );

{═══════════════════════════════════════════════════════════════════════════════}
{  РІВЕНЬ 4: ЦЕНТРАЛІЗОВАНА СТРУКТУРА ДАНИХ (TPaymentInfo)                      }
{═══════════════════════════════════════════════════════════════════════════════}

type
  TPaymentInfo = record
    PaymentTypeUI: string;
    SubTypeUI: string;
    ProviderUI: string;
    PaymentTypeCode: Integer;
    SubTypeCode: Integer;
    ProviderAPI: string;
    CashAmount: Double;
    CardAmount: Double;
    CardMask: string;
    AuthCode: string;
    RRN: string;
    IBAN: string;
    RecipientName: string;
    PaymentPurpose: string;
  end;
  {═══════════════════════════════════════════════════════════════════════════════}
  {  OFFLINE-КОДИ (E1)                                                          }
  {═══════════════════════════════════════════════════════════════════════════════}

  TOfflineCode = record
    ID: Integer;              // локальний ID у CHEK_OFFLINE_FISCAL_CODES (0 = ще не вставлено)
    FiscalCode: string;       // fiscal_code з API Checkbox
    CashRegisterID: string;   // наш CASH_REGISTER_ID
  end;

  TOfflineCodeArray = array of TOfflineCode;
  {═══════════════════════════════════════════════════════════════════════════════}
  {  Статуси OFFLINE_RECEIPTS_QUEUE (E3)                                          }
  {═══════════════════════════════════════════════════════════════════════════════}
 const
    QS_PENDING   = 'ОЧІКУЄ';
    QS_SENT      = 'ВІДПРАВЛЕНО';
    QS_SYNCED    = 'СИНХРОНІЗОВАНО';
    QS_ERROR     = 'ПОМИЛКА';
    QS_CANCELLED = 'СКАСОВАНО';

 type
    TQueueItem = record
      ID: Integer;                // OFFLINE_RECEIPTS_QUEUE.ID
      CheckID: Integer;           // CHEK.KOD
      ReceiptUUID: string;        // RECEIPT_UUID (наш UUID чека)
      ReceiptJSON: string;        // RECEIPT_JSON
      FIScalCode: string;         // FISCAL_CODE (наш offline-код)
      Status: string;             // STATUS
      LastRetryAt: TDateTime;     // LAST_RETRY_AT
    end;

    TQueueItemArray = array of TQueueItem;

  {═══════════════════════════════════════════════════════════════════════════════}
  {  РІВЕНЬ 5: ФІСКАЛЬНІ СТАТУСИ ЧЕКА (CHEK.FISCAL_STATUS)                        }
  {═══════════════════════════════════════════════════════════════════════════════}

  const
    FS_PENDING     = 'ОЧІКУЄ';
    FS_SENT        = 'ВІДПРАВЛЕНО';
    FS_DONE        = 'ФІСКАЛІЗОВАНО';
    FS_ERROR       = 'ПОМИЛКА';
    FS_NON_FISCAL  = 'НЕФІСКАЛЬНИЙ';
    FS_CANCELLED   = 'СКАСОВАНО';



{═══════════════════════════════════════════════════════════════════════════════}
{  ФУНКЦІЇ ПЕРЕТВОРЕННЯ: ТИПИ ОПЛАТИ                                           }
{═══════════════════════════════════════════════════════════════════════════════}

function PaymentTypeUIToCode(const AUI: string): Integer;
function PaymentTypeCodeToUI(ACode: Integer): string;
function PaymentTypeUIToAPI(const AUI: string): string;
function PaymentTypeAPIToUI(const AAPI: string): string;
function PaymentTypeCodeToAPI(ACode: Integer): string;
function PaymentTypeAPIToCode(const AAPI: string): Integer;
function PaymentTypeUIEnumToCode(AUI: TPaymentTypeUI): Integer;
function PaymentTypeAPIEnumToCode(AAPI: TPaymentTypeAPI): Integer;

{═══════════════════════════════════════════════════════════════════════════════}
{  ФУНКЦІЇ ПЕРЕТВОРЕННЯ: ПІДТИПИ (виправлено Ord → Integer)                    }
{═══════════════════════════════════════════════════════════════════════════════}

function SubTypeUIToCode(const AUI: string): Integer;
function SubTypeCodeToUI(ACode: Integer): string;
function SubTypeUIToAPI(const AUI: string): string;
function SubTypeAPIToUI(const AAPI: string): string;
function SubTypeCodeToAPI(ACode: Integer): string;
function SubTypeAPIToCode(const AAPI: string): Integer;
function SubTypeEnumToUI(ASubType: TCashlessSubType): string;
function SubTypeEnumToAPI(ASubType: TCashlessSubType): string;
function SubTypeEnumToCode(ASubType: TCashlessSubType): Integer;

{═══════════════════════════════════════════════════════════════════════════════}
{  ФУНКЦІЇ ПЕРЕТВОРЕННЯ: ПРОВАЙДЕРИ                                           }
{═══════════════════════════════════════════════════════════════════════════════}

function ProviderUIToAPI(const AUI: string): string;
function ProviderAPIToUI(const AAPI: string): string;
function ProviderIndexToUI(AIndex: Integer): string;
function ProviderIndexToAPI(AIndex: Integer): string;

{═══════════════════════════════════════════════════════════════════════════════}
{  ДОПОМІЖНІ ФУНКЦІЇ (виправлено Ord → Integer)                                }
{═══════════════════════════════════════════════════════════════════════════════}

function IsCardSubType(ACode: Integer): Boolean;
function IsTransferSubType(ACode: Integer): Boolean;
function PaymentTypeCodeToEnum(ACode: Integer): TPaymentTypeUI;
function PaymentTypeCodeToAPIEnum(ACode: Integer): TPaymentTypeAPI;
function SubTypeCodeToEnum(ACode: Integer): TCashlessSubType;
function IsValidSubType(const ASubType: string): Boolean;

{-------------------------------------------------------------------------------}
function IsFiscalStatusDone(const AStatus: string): Boolean;
function IsFiscalStatusModifiable(const AStatus: string): Boolean;


function ValidateIBAN(const AIBAN: string): Boolean;
function ValidateCardMask(const AMask: string): Boolean;
function ValidateRRN(const ARRN: string): Boolean;
function ValidateAuthCode(const ACode: string): Boolean;


implementation

{═══════════════════════════════════════════════════════════════════════════════}
{  РЕАЛІЗАЦІЯ: ТИПИ ОПЛАТИ                                                     }
{═══════════════════════════════════════════════════════════════════════════════}

function PaymentTypeUIToCode(const AUI: string): Integer;
var
  I: TPaymentTypeUI;
begin
  for I := Low(PaymentTypeUI_Names) to High(PaymentTypeUI_Names) do
    if PaymentTypeUI_Names[I] = AUI then
    begin
      Result := PaymentType_Numbers[I];
      Exit;
    end;
  Result := 0;
end;

function PaymentTypeCodeToUI(ACode: Integer): string;
var
  I: TPaymentTypeUI;
begin
  for I := Low(PaymentType_Numbers) to High(PaymentType_Numbers) do
    if PaymentType_Numbers[I] = ACode then
    begin
      Result := PaymentTypeUI_Names[I];
      Exit;
    end;
  Result := '';
end;

function PaymentTypeUIToAPI(const AUI: string): string;
var
  Code: Integer;
begin
  Code := PaymentTypeUIToCode(AUI);
  Result := PaymentTypeCodeToAPI(Code);
end;

function PaymentTypeAPIToUI(const AAPI: string): string;
var
  Code: Integer;
begin
  Code := PaymentTypeAPIToCode(AAPI);
  Result := PaymentTypeCodeToUI(Code);
end;

function PaymentTypeCodeToAPI(ACode: Integer): string;
begin
  case ACode of
    1: Result := PaymentTypeAPI_Codes[ptaCash];
    2: Result := PaymentTypeAPI_Codes[ptaCashless];
    3: Result := PaymentTypeAPI_Codes[ptaMixed];
    4: Result := PaymentTypeAPI_Codes[ptaOther];
  else
    Result := '';
  end;
end;

function PaymentTypeAPIToCode(const AAPI: string): Integer;
var
  I: TPaymentTypeAPI;
begin
  for I := Low(PaymentTypeAPI_Codes) to High(PaymentTypeAPI_Codes) do
    if PaymentTypeAPI_Codes[I] = AAPI then
    begin
      case I of
        ptaCash:     Result := 1;
        ptaCashless: Result := 2;
        ptaMixed:    Result := 3;
        ptaOther:    Result := 4;
      end;
      Exit;
    end;
  Result := 0;
end;

function PaymentTypeUIEnumToCode(AUI: TPaymentTypeUI): Integer;
begin
  Result := PaymentType_Numbers[AUI];
end;

function PaymentTypeAPIEnumToCode(AAPI: TPaymentTypeAPI): Integer;
begin
  case AAPI of
    ptaCash:     Result := 1;
    ptaCashless: Result := 2;
    ptaMixed:    Result := 3;
    ptaOther:    Result := 4;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  РЕАЛІЗАЦІЯ: ПІДТИПИ (виправлено)                                            }
{═══════════════════════════════════════════════════════════════════════════════}

function SubTypeUIToCode(const AUI: string): Integer;
var
  I: Integer;
begin
  for I := Low(CashlessSubTypeUI_Names) to High(CashlessSubTypeUI_Names) do
    if CashlessSubTypeUI_Names[I] = AUI then
    begin
      Result := I;
      Exit;
    end;
  Result := 0;
end;

function SubTypeCodeToUI(ACode: Integer): string;
begin
  if (ACode >= Low(CashlessSubTypeUI_Names)) and
     (ACode <= High(CashlessSubTypeUI_Names)) then
    Result := CashlessSubTypeUI_Names[ACode]
  else
    Result := '';
end;

function SubTypeUIToAPI(const AUI: string): string;
var
  Code: Integer;
begin
  Code := SubTypeUIToCode(AUI);
  Result := SubTypeCodeToAPI(Code);
end;

function SubTypeAPIToUI(const AAPI: string): string;
var
  Code: Integer;
begin
  Code := SubTypeAPIToCode(AAPI);
  Result := SubTypeCodeToUI(Code);
end;

function SubTypeCodeToAPI(ACode: Integer): string;
begin
  if (ACode >= Low(CashlessSubTypeAPI_Codes)) and
     (ACode <= High(CashlessSubTypeAPI_Codes)) then
    Result := CashlessSubTypeAPI_Codes[ACode]
  else
    Result := '';
end;

function SubTypeAPIToCode(const AAPI: string): Integer;
var
  I: Integer;
begin
  for I := Low(CashlessSubTypeAPI_Codes) to High(CashlessSubTypeAPI_Codes) do
    if CashlessSubTypeAPI_Codes[I] = AAPI then
    begin
      Result := I;
      Exit;
    end;
  Result := 0;
end;

// ВИПРАВЛЕНО: замість Ord використовуємо Integer
function SubTypeEnumToUI(ASubType: TCashlessSubType): string;
begin
  Result := CashlessSubTypeUI_Names[Integer(ASubType)];
end;

function SubTypeEnumToAPI(ASubType: TCashlessSubType): string;
begin
  Result := CashlessSubTypeAPI_Codes[Integer(ASubType)];
end;

function SubTypeEnumToCode(ASubType: TCashlessSubType): Integer;
begin
  Result := Integer(ASubType);
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  РЕАЛІЗАЦІЯ: ПРОВАЙДЕРИ                                                     }
{═══════════════════════════════════════════════════════════════════════════════}

function ProviderUIToAPI(const AUI: string): string;
var
  I: Integer;
begin
  for I := Low(CardProviderUI_Names) to High(CardProviderUI_Names) do
    if CardProviderUI_Names[I] = AUI then
    begin
      Result := CardProviders[I];
      Exit;
    end;
  Result := '';
end;

function ProviderAPIToUI(const AAPI: string): string;
var
  I: Integer;
begin
  for I := Low(CardProviders) to High(CardProviders) do
    if CardProviders[I] = AAPI then
    begin
      Result := CardProviderUI_Names[I];
      Exit;
    end;
  Result := '';
end;

function ProviderIndexToUI(AIndex: Integer): string;
begin
  if (AIndex >= Low(CardProviderUI_Names)) and
     (AIndex <= High(CardProviderUI_Names)) then
    Result := CardProviderUI_Names[AIndex]
  else
    Result := '';
end;

function ProviderIndexToAPI(AIndex: Integer): string;
begin
  if (AIndex >= Low(CardProviders)) and
     (AIndex <= High(CardProviders)) then
    Result := CardProviders[AIndex]
  else
    Result := '';
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  РЕАЛІЗАЦІЯ: ДОПОМІЖНІ ФУНКЦІЇ (виправлено)                                 }
{═══════════════════════════════════════════════════════════════════════════════}

function IsCardSubType(ACode: Integer): Boolean;
begin
  Result := ACode = Integer(cstCard);
end;

function IsTransferSubType(ACode: Integer): Boolean;
begin
  Result := (ACode = Integer(cstTransferNNPP)) or
            (ACode = Integer(cstTransferPTKS)) or
            (ACode = Integer(cstCurrentAccount));
end;

function PaymentTypeCodeToEnum(ACode: Integer): TPaymentTypeUI;
begin
  case ACode of
    1: Result := ptuCash;
    2: Result := ptuCashless;
    3: Result := ptuMixed;
    4: Result := ptuOther;
  else
    Result := ptuCash;
  end;
end;

function PaymentTypeCodeToAPIEnum(ACode: Integer): TPaymentTypeAPI;
begin
  case ACode of
    1: Result := ptaCash;
    2: Result := ptaCashless;
    3: Result := ptaMixed;
    4: Result := ptaOther;
  else
    Result := ptaCash;
  end;
end;

// ВИПРАВЛЕНО: використовуємо Integer замість Ord
function SubTypeCodeToEnum(ACode: Integer): TCashlessSubType;
begin
  if (ACode >= Integer(Low(TCashlessSubType))) and
     (ACode <= Integer(High(TCashlessSubType))) then
    Result := TCashlessSubType(ACode)
  else
    Result := cstCard;
end;

function IsValidSubType(const ASubType: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(CashlessSubTypeUI_Names) to High(CashlessSubTypeUI_Names) do
    if CashlessSubTypeUI_Names[i] = ASubType then
      Exit(True);
end;

function IsFiscalStatusDone(const AStatus: string): Boolean;
begin
  Result := AStatus = FS_DONE;
end;

function IsFiscalStatusModifiable(const AStatus: string): Boolean;
begin
  Result := (AStatus = FS_PENDING) or (AStatus = FS_NON_FISCAL) or (AStatus = '') or (AStatus = FS_CANCELLED);
end;


function ValidateIBAN(const AIBAN: string): Boolean;
begin
  Result := (Length(AIBAN) = 29) and
            (Copy(AIBAN, 1, 2) = 'UA') and
            (StrToIntDef(Copy(AIBAN, 3, 27), -1) >= 0);
end;

function ValidateCardMask(const AMask: string): Boolean;
var
  i, DigitCount: Integer;
begin
  Result := False;
  if (Length(AMask) < 4) or (Length(AMask) > 19) then Exit;
  DigitCount := 0;
  for i := 1 to Length(AMask) do
  begin
    if AMask[i] in ['0'..'9'] then Inc(DigitCount)
    else if AMask[i] <> '*' then Exit;
  end;
  Result := DigitCount >= 4;
end;

function ValidateRRN(const ARRN: string): Boolean;
begin
  Result := (Length(ARRN) = 12) and (StrToInt64Def(ARRN, -1) >= 0);
end;

function ValidateAuthCode(const ACode: string): Boolean;
begin
  Result := (Length(ACode) = 6) and (StrToIntDef(ACode, -1) >= 0);
end;

end.
