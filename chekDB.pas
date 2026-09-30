unit chekdb;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, DB, SQLDB, DataMod, chekno, Controls, Dialogs,
  DGSer, otov, sprop, chektypes, dndata, uAutoTransfer, uAppConfig;
type
  // Тип для процедури логування
  TLogProcedure = procedure(const AMessage: string) of object;

  // Record для збереження реквізитів оплати (оновлений згідно завдання)
  TPaymentDetails = record
    PaymentTypeUI: string;      // українська назва типу (з БД)
    SubTypeUI: string;          // українська назва підтипу (з БД)
    PaymentTypeCode: Integer;   // числовий код (PAYMENT_TYPE_I)
    SubTypeCode: Integer;       // числовий код (PAYMENT_SUBTYPE_I)
    CashAmount: Double;
    CardAmount: Double;
    IBAN: string;
    RecipientName: string;
    PaymentPurpose: string;
    CardMask: string;
    AuthCode: string;
    RRN: string;
    ProviderType: string;
    TerminalId: string;
  end;

  //тип  тільки для передачі результату додавання товару
  TAddProductResult = (
    aprNone,              // нічого не додано / скасовано
    aprAdded,             // товар додано, серійники не потрібні
    aprNeedSerialSelect,  // товар додано, потрібно вибрати 1 серійник (VibSer)
    aprNeedSerialsRemind  // товар додано, потрібно нагадати про кілька серійників
  );


  { TChekDBManager }
  TChekDBManager = class(TObject)
  private
    FDataModule: TDMMag;
    FOnLog: TLogProcedure;
    FCurrentKlient: Integer;
    FCurrentSchet: Integer;
    FSavedChekPos: Integer;
    FSavedNDataPos: Integer;

    procedure Log(const AMessage: string);
    procedure SafeExecSQL(const SQLText: string); // Безпечне виконання SQL

    // Допоміжна функція для конвертації старих типів оплати (тимчасово)
    function ConvertOldPaymentTypeToNew(const OldType: string; out NewTypeUI: string; out NewSubTypeUI: string): Boolean;

  public
    datavv, nomer, psvid, nalkod, pnazva, pnazshort: string;  // Дані для звітів
    knazva: string; //назва клієнта для збереження чеків
    constructor Create(ADataModule: TDMMag; ALogProcedure: TLogProcedure);
    destructor Destroy; override;
    function AfterCreate(TempCurrentKlient: integer): Boolean;

    property SavedChekPos: integer read FSavedChekPos write FSavedChekPos;
    property SavedNDataPos: integer read FSavedNDataPos write FSavedNDataPos;
    property CurrentSchet: integer read FCurrentSchet write FCurrentSchet;
    property CurrentKlient: integer read FCurrentKlient write FCurrentKlient;

    // Основні методи роботи з транзакціями та позиціями
    procedure SavPos;
    procedure RstPos;
    procedure OpnCon;
    procedure ClsCon;

    // Допоміжні методи роботи зі з'єднанням
    procedure SafeCommitAndReopenConnection;
    procedure SaveConnectionState(out ChekPos, NDataPos: Integer);
    procedure RestoreConnectionState(ChekPos, NDataPos: Integer);

    // Методи роботи з чеками (оновлені сигнатури)
    function CreateNewCheck(SchetID: Integer; IsFiscal: Boolean = True;
      PaymentTypeUI: string = 'Готівка'; PaymentSubTypeUI: string = '';
      const IBAN: string = ''; const RecipientName: string = '';
      const PaymentPurpose: string = ''; const ProviderType: string = '';
      Note: string = ''): Integer;
    function DeleteCheck: Boolean;
    function CanDeleteCheck(CheckID: Integer): Boolean;

    // Методи перевірки статусу чеків
    function GetCheckFiscalStatus(CheckID: Integer): string;
    function IsCheckFiscalized(CheckID: Integer): Boolean;
    function CanModifyCheck: Boolean;

    function GetCheckDetails(CheckID: Integer; out CheckNumber: Integer; out FiscalStatus: string; out HasProducts: Boolean): Boolean;

    function GetFiscalRetryCount(CheckID: Integer): Integer;
    procedure ResetFiscalRetryCount(CheckID: Integer);
    procedure SetFiscalRetryCount(CheckID: Integer; RetryCount: Integer);

    function ValidateCheckSums(CheckID: Integer; out TotalFromGoods, CheckSum: Double): Boolean;
    function ValidateCheckForFiscalizationEx(CheckID: Integer; out ErrorMessage: string): Boolean;

    // Методи конвертації чеків
    procedure ConvertToNonFiscal(CheckID: Integer);
    procedure ConvertToFiscal(CheckID: Integer);

    // Методи роботи з товарами
    function AddProductToCheck: TAddProductResult;
    procedure RemoveProductFromCheck(ProductDataID: Integer);
    function GetProductInfo(ProductDataID: Integer; out ProductName: string; out CheckID: Integer): Boolean;
    procedure UpdateProductInCheck;
    procedure VibSer;

    // Методи фіскального статусу
    procedure SetCheckFiscalStatus(CheckID: Integer; Status: string;
      FiscalData: string = ''; ErrorText: string = '');
    procedure MarkCheckAsFiscalized(CheckID: Integer; FiscalCode: string;
      FiscalID: string; ShiftID: string; CashRegisterID: string);
    procedure UpdateFiscalRetryCount(CheckID: Integer; RetryCount: Integer);
    // === E1.2: Offline-коди ===
    function SaveOfflineCodes(const ACodes: TOfflineCodeArray;
      const ACashierLogin: string): Integer;
    function AllocateOfflineCode(const ACR, APurpose: string;
      out ACode: TOfflineCode): Boolean;
    function CountFreeOfflineCodes(const ACR: string): Integer;
    function CountReservedOrphans(const ACR: string): Integer;
    function CleanupOrphanOfflineCodes(const ACR: string): Integer;
    // Валідація та утиліти
    function ValidateCheckIntegrity(CheckID: Integer): Boolean;

    function GetCurrentProductID: Integer;
    function GetCurrentProductName: string;

    // Друк
    function CheckPrinting: Boolean;
    function GetNextCheckNumber(SchetID: Integer): Integer;
    procedure AssignCheckNumber(CheckID, CheckNumber, SchetID: Integer);
    function GetProdavecID(SchetID: Integer): Integer;
    function GetLastCheckNumber(ProdavecID: Integer): Integer;
    procedure CancelCheckNumber(CheckID, SchetID: Integer);

    // гарантія
    function GetWarrantyProducts(CheckID, SchetID: Integer): TDataSet;
    procedure CloseWarrantyDataSet;

    procedure UpdateFiscalStatus(CheckID: Integer; Status: string;
                FiscalData: string = ''; ErrorText: string = '');
    procedure HandleFiscalizationException(ACheckID: Integer; E: Exception);
    procedure UpdateFiscalStatusInDB(CheckID: Integer; Status: string;
      FiscalData: string = ''; ErrorText: string = ''; FiscalId: string = '';
      FiscalCode: string = ''; FiscalSerial: Integer = -1;
      ShiftId: string = ''; CashRegisterId: string = ''; RetryCount: Integer = -1);
    procedure MarkCheckAsPrinted(CheckID: Integer);
    procedure RefreshDatasets(CurrentCheckID: Integer);
    procedure ValidateAndRepairCheckData(CheckID: Integer);

    // Оновлений метод оновлення оплати (з українськими назвами)
    procedure UpdatePaymentInfo(CheckID: Integer; PaymentTypeUI: string;
        CashAmount: Double; CardAmount: Double; PaymentSubTypeUI: string = '';
        const IBAN: string = ''; const RecipientName: string = '';
        const PaymentPurpose: string = ''; const CardMask: string = '';
        const AuthCode: string = ''; const RRN: string = '';
        const ProviderType: string = ''; const TerminalId: string = '');
    procedure LogDatabaseState;

    function LocateCheck(CheckID: Integer): Boolean;
    function GetCheckTotal(CheckID: Integer): Double;
    function GetCurrentPaymentType: string;

    function ClearSerialNumberAssignment: Boolean;

    // Оновлений метод отримання деталей оплати
    function GetPaymentDetails(CheckID: Integer; out Details: TPaymentDetails): Boolean;

    // === E2.1: Offline-продаж (атомарно: INSERT queue + UPDATE CHEK + прив'язка коду) ===
    function SaveOfflineSaleTransaction(
      ACheckID: Integer;
      const ACashRegisterID, ACashierLogin, AShiftID: string;
      const AReceiptUUID, AJsonString: string;
      const ACode: TOfflineCode;
      out AError: string): Boolean;

    // === E2.3: Локальні ліміти 36/168 (ТЗ §3.5) ===
    function CheckOfflineLimits(const ACR: string; out AError: string): Boolean;

    // === E2.4: Локальний стан каси (ТЗ §3.1) ===
    function IsOfflineState(const ACR: string): Boolean;
    // === E3.1: Управління offline-станом каси ===
    // UPSERT: IS_OFFLINE=1, OFFLINE_STARTED_AT=NOW, OFFLINE_MONTH='YYYY-MM'.
    // LAST_OFFLINE_SEQ_NUMBER не скидається (ТЗ §3.2 — скидання лише після go-online).
    function UpdateOfflineStateStart(const ACR: string; out AError: string): Boolean;

    // UPDATE: IS_OFFLINE=0, LAST_ONLINE_AT=NOW, LAST_OFFLINE_SEQ_NUMBER=0.
    function UpdateOfflineStateStop(const ACR: string): Boolean;

    // Кеш балансу на момент go-offline (NUMERIC(18,2) — гривні з копійками).
    procedure CacheBalance(const ACR: string;
      ABalance, ACashSales, ACardSales: Double);

    // === E3.3.1: Черга sync ===
    // Читає чергу для каси. Тільки STATUS IN ('ОЧІКУЄ','ВІДПРАВЛЕНО').
    // Не тримає курсор — повертає масив.
    function LoadPendingQueue(const ACR: string): TQueueItemArray;

    // Оновлює статус черги. RetryDelta > 0 — інкремент RETRY_COUNT.
    // Оновлює LAST_RETRY_AT = CURRENT_TIMESTAMP.
    procedure SetQueueStatus(AQueueID: Integer; const AStatus, AError: string;
      ARetryDelta: Integer = 0);

    // Атомарно (одна транзакція):
    //   1) UPDATE OFFLINE_RECEIPTS_QUEUE — STATUS='СИНХРОНІЗОВАНО', SYNCED_AT=NOW,
    //      FISCAL_RESPONSE=<перші 500 символів>
    //   2) UPDATE CHEK — FISCAL_STATUS='ФІСКАЛІЗОВАНО', FISCAL_CODE,
    //      FISCAL_ID, FISCAL_DATE=NOW
    //   3) UPDATE CHEK_OFFLINE_FISCAL_CODES — STATUS=2, USED_AT=NOW
    function MarkSynced(AQueueID, ACheckID: Integer;
      const AFiscalCode, AFiscalID, AResponseJSON: string;
      out AError: string): Boolean;
    // === E3.3.2: Leader-lock для multi-PC (ТЗ §3.8) ===
    // Спроба захопити lock. TimeoutMin з ReadSyncLockTimeoutMin (5..120).
    // RowsAffected > 0 → lock отримано.
    function TryAcquireLock(const ACR, AOwner: string;
      ATimeoutMin: Integer): Boolean;

    // Heartbeat: оновлює SYNC_LOCKED_AT, якщо власник — ми.
    procedure RefreshLock(const ACR, AOwner: string);

    // Перевірка: чи ми досі власник lock.
    function IsSyncLockOwner(const ACR, AOwner: string): Boolean;

    // Звільнення lock (викликати у finally).
    procedure ReleaseLock(const ACR, AOwner: string);
    // Звільнення RESERVED-коду (для cleanup при JSON-build fail у chek.pas)
    procedure ReleaseReservedCode(AID: Integer);
  end;

implementation

{ TChekDBManager }

constructor TChekDBManager.Create(ADataModule: TDMMag; ALogProcedure: TLogProcedure);
begin
  inherited Create;
  FDataModule := ADataModule;
  FOnLog := ALogProcedure;
  FSavedChekPos := 0;
  FSavedNDataPos := 0;
  Log('TChekDBManager створено');
end;

function TChekDBManager.AfterCreate(TempCurrentKlient: integer): Boolean;
var
   TempCurrentSchet: integer;
   nsch, rkv, vr: integer;
begin
  Result := False;
  TempCurrentSchet := 0;

  // 0.3. операції з БД
  FDataModule.readconf;

  if TempCurrentKlient > 0 then
  begin
    // Заповнюємо QKl для можливого використання формою
    FDataModule.QKl.SQL.Clear;
    FDataModule.QKl.SQL.Add('select * from klient where kod=' + IntToStr(TempCurrentKlient));

    // Отримуємо назву клієнта для змінної pnazva (використовується в звітах)
    knazva := FDataModule.ZaprosString('NAZVA',
      'select nazva from klient where kod=' + IntToStr(TempCurrentKlient));
  end
  else
  begin
    // Клієнт не заданий — помітка для звітів
    knazva := 'Не задано місце зберігання чеків';
    Log('⚠️ ' + knazva);
    Exit; // Result = False
  end;

  FDataModule.TrMag.StartTransaction;
  try
    FDataModule.SQLQ.SQL.Clear;
    FDataModule.SQLQ.SQL.Add('select kod from schet where klient=' + IntToStr(TempCurrentKlient) +
                             ' and data_vv=' + #39 + FormatDateTime('dd.mm.yyyy', Date) + #39);
    FDataModule.SQLQ.Active := true;

    if FDataModule.SQLQ.FieldByName('KOD').IsNull then
    begin
      FDataModule.SQLQ.Active := false;
      FDataModule.TrMag.Commit;

      if TempCurrentKlient > 0 then
      begin
        vr := FDataModule.Zapros('VID_RAS',
          'select VID_RAS from klient where kod=' + IntToStr(TempCurrentKlient));
        nsch := FDataModule.Zapros('max',
          'select max(nomer) from schet') + 1;
        rkv := FDataModule.Zapros('rekvizit',
          'select rekvizit from klient where kod=' + IntToStr(TempCurrentKlient));

        FDataModule.LaunchQuery(FDataModule.SQLQ, FDataModule.TrMag,
           'insert into schet(klient,data_vv,nomer,rekvizit,vid_ras,nazva,sch_summa,nak_summa,nak_summa_prih,nak_fin_rez,priznak,kr_prizn) '+
            'values(' + IntToStr(TempCurrentKlient) + ',' +
            #39 + FormatDateTime('dd.mm.yyyy', Date) + #39 + ',' +
            IntToStr(nsch) + ',' +
            IntToStr(rkv) + ',' +
            IntToStr(vr) + ',' +
            #39 + pnazva + #39 + ',' +  // Використовуємо pnazva замість Label1.Caption
            '0,0,0,0,0,0)');

        FDataModule.TrMag.StartTransaction;
        FDataModule.SQLQ.SQL.Clear;
        FDataModule.SQLQ.SQL.Add('select kod from schet where klient=' + IntToStr(TempCurrentKlient) +
                                 ' and data_vv=' + #39 + FormatDateTime('dd.mm.yyyy', Date) + #39);
        FDataModule.SQLQ.Active := true;
      end
      else
      begin
        Log('❌ Операція неможлива (клієнт?)');
        Exit; // Result = False
      end;
    end;

    TempCurrentSchet := FDataModule.SQLQ.FieldByName('KOD').AsInteger;
    FDataModule.SQLQ.Active := false;

    // {============} Отримання реквізитів для звітів {============}
    FDataModule.SQLQ.SQL.Clear;
    FDataModule.SQLQ.SQL.Add('select s.nomer, s.data_vv, p.nal_kod as nal_kod, p.svid as psvid, p.nazva as pnazva, p.nazshort as pnazshort');
    FDataModule.SQLQ.SQL.Add('from schet s, rekvizit r, prodavec p');
    FDataModule.SQLQ.SQL.Add('where s.kod=' + IntToStr(TempCurrentSchet));
    FDataModule.SQLQ.SQL.Add('and s.rekvizit=r.kod and r.prodavec=p.kod');
    FDataModule.SQLQ.Active := true;

    if FDataModule.SQLQ.FieldByName('nomer').IsNull then
      nomer := ''
    else
      nomer := FDataModule.SQLQ.FieldByName('nomer').AsString;

    if FDataModule.SQLQ.FieldByName('data_vv').IsNull then
      datavv := '"____"________________________20____р.'
    else
      datavv := DecDate(FDataModule.SQLQ.FieldByName('data_vv').AsDateTime);

    if FDataModule.SQLQ.FieldByName('nal_kod').IsNull then
      nalkod := ''
    else
      nalkod := FDataModule.SQLQ.FieldByName('nal_kod').AsString;

    if FDataModule.SQLQ.FieldByName('psvid').IsNull then
      psvid := ''
    else
      psvid := FDataModule.SQLQ.FieldByName('psvid').AsString;

    if FDataModule.SQLQ.FieldByName('pnazva').IsNull then
      pnazva := ''
    else
      pnazva := FDataModule.SQLQ.FieldByName('pnazva').AsString;

    if FDataModule.SQLQ.FieldByName('pnazshort').IsNull then
      pnazshort := ''
    else
      pnazshort := FDataModule.SQLQ.FieldByName('pnazshort').AsString;

    FDataModule.SQLQ.Active := false;
    // {===========}

    FDataModule.TrMag.Commit;

    FCurrentSchet := TempCurrentSchet;
    FCurrentKlient := TempCurrentKlient;

    Log('✅ Менеджер БД ініціалізовано з schet=' + IntToStr(FCurrentSchet) +
        ' Клієнт:' + IntToStr(FCurrentKlient));


    FDataModule.QChek.SQL.Clear;
    FDataModule.QChek.SQL.Add('select * from chek where schet='+inttostr(FCurrentSchet)+' order by kod');
    {-------------------------------}
    FDataModule.schb1:=true;
    FDataModule.schb3:=false;
    FDataModule.frk:=0;
    FDataModule.ssort:=2;
    OpnCon;
    FDataModule.QChek.Last;

    Result := True;
  except
    on E: Exception do
    begin
      if FDataModule.TrMag.Active then
        FDataModule.TrMag.Rollback;
      Log('❌ Помилка AfterCreate: ' + E.Message);
      Result := False;
    end;
  end;
end;

destructor TChekDBManager.Destroy;
begin
  Log('TChekDBManager знищено');
  inherited Destroy;
end;

procedure TChekDBManager.Log(const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMessage);
end;

procedure TChekDBManager.SafeExecSQL(const SQLText: string);
begin
  // Перевірка стану з'єднання
  if not FDataModule.TrMag.Active then
    FDataModule.TrMag.StartTransaction;

  FDataModule.SQLQ.Close;
  FDataModule.SQLQ.SQL.Text := SQLText;
  FDataModule.SQLQ.ExecSQL;

  // Коміт змін
  if FDataModule.TrMag.Active then
    FDataModule.TrMag.Commit;
end;

// Методи роботи з транзакціями та позиціями

procedure TChekDBManager.SavPos;
begin
  FSavedChekPos := 0;
  FSavedNDataPos := 0;
  if not FDataModule.QChekKOD.IsNull then
    FSavedChekPos := FDataModule.QChekKOD.AsInteger;
  if not FDataModule.QNDataKOD.IsNull then
    FSavedNDataPos := FDataModule.QNDataKOD.AsInteger;
  Log(Format('Збережено позиції: Chek=%d, NData=%d', [FSavedChekPos, FSavedNDataPos]));
end;

procedure TChekDBManager.RstPos;
begin
  if FSavedChekPos > 0 then
    FDataModule.QChek.Locate('kod', FSavedChekPos, []);
  if FSavedNDataPos > 0 then
    FDataModule.QNData.Locate('kod', FSavedNDataPos, []);
  Log(Format('Відновлено позиції: Chek=%d, NData=%d', [FSavedChekPos, FSavedNDataPos]));
end;

procedure TChekDBManager.OpnCon;
begin
  if not FDataModule.TrMag.Active then
    FDataModule.TrMag.StartTransaction;
  if not FDataModule.QNSer.Active then
    FDataModule.QNSer.Active := True;
  if not FDataModule.QNData.Active then
    FDataModule.QNData.Active := True;
  if not FDataModule.QChek.Active then
    FDataModule.QChek.Active := True;
  Log('Відкрито зʼєднання з БД');
end;

procedure TChekDBManager.ClsCon;
begin
  if FDataModule.QChek.Active then
    FDataModule.QChek.Active := False;
  if FDataModule.QNData.Active then
    FDataModule.QNData.Active := False;
  if FDataModule.QNSer.Active then
    FDataModule.QNSer.Active := False;
  if FDataModule.TrMag.Active then
    FDataModule.TrMag.Commit;
  Log('Закрито зʼєднання з БД');
end;

// Допоміжні методи роботи зі з'єднанням

procedure TChekDBManager.SafeCommitAndReopenConnection;
var
  //SavedChekPos, SavedNDataPos: Integer;
  WasInTransaction: Boolean;
begin
  SavedChekPos := 0;
  SavedNDataPos := 0;
  WasInTransaction := False;

  try
    Log('🔁 SafeCommitAndReopenConnection: Початок безпечного коміту та перевідкриття зʼєднання');

    // 1. Збереження позицій курсорів
    if not DMMag.QChekKOD.IsNull then
      SavedChekPos := DMMag.QChekKOD.AsInteger;

    if not DMMag.QNDataKOD.IsNull then
      SavedNDataPos := DMMag.QNDataKOD.AsInteger;

    Log(Format('Збережено позиції: Chek=%d, NData=%d', [SavedChekPos, SavedNDataPos]));

    // 2. Перевірка та коміт транзакції
    WasInTransaction := DMMag.TrMag.Active;
    if WasInTransaction then
    begin
      Log('Виконується коміт активной транзакції...');
      DMMag.TrMag.Commit;
      Log('✅ Транзакцію успішно закомічено');
    end
    else
    begin
      Log('ℹ️ Активної транзакції не знайдено, продовжуємо...');
    end;

    // 3. Закриття зʼєднань
    Log('Закриття зʼєднань з БД...');
    if DMMag.QChek.Active then
      DMMag.QChek.Active := False;
    if DMMag.QNData.Active then
      DMMag.QNData.Active := False;
    if DMMag.QNSer.Active then
      DMMag.QNSer.Active := False;

    // 4. Перевідкриття зʼєднань
    Log('Перевідкриття зʼєднань з БД...');
    DMMag.TrMag.StartTransaction;
    DMMag.QNSer.Active := True;
    DMMag.QNData.Active := True;
    DMMag.QChek.Active := True;
    Log('✅ Зʼєднання з БД успішно перевідкрито');

    // 5. Відновлення позицій курсорів
    Log('Відновлення позицій курсорів...');

    if SavedChekPos > 0 then
    begin
      if DMMag.QChek.Locate('KOD', SavedChekPos, []) then
        Log(Format('✅ Позицію Chek відновлено: KOD=%d', [SavedChekPos]))
      else
        Log('⚠️ Не вдалося відновити позицію Chek, використовується перший запис');
    end;

    if SavedNDataPos > 0 then
    begin
      if DMMag.QNData.Locate('KOD', SavedNDataPos, []) then
        Log(Format('✅ Позицію NData відновлено: KOD=%d', [SavedNDataPos]))
      else
        Log('⚠️ Не вдалося відновити позицію NData, використовується перший запис');
    end;

    Log('✅ SafeCommitAndReopenConnection успішно завершено');

  except
    on E: Exception do
    begin
      Log('❌ ПОМИЛКА в SafeCommitAndReopenConnection: ' + E.Message);

      // Спроба аварійного відновлення
      try
        if DMMag.TrMag.Active then
          DMMag.TrMag.Rollback;

        // Повторна ініціалізація зʼєднання
        DMMag.TrMag.StartTransaction;
        DMMag.QNSer.Active := True;
        DMMag.QNData.Active := True;
        DMMag.QChek.Active := True;

        Log('🔄 Зʼєднання з БД аварійно відновлено');
      except
        on E2: Exception do
        begin
          Log('💥 КРИТИЧНА ПОМИЛКА: не вдалося відновити зʼєднання з БД: ' + E2.Message);
          raise; // Перевикидання винятку для обробки вище
        end;
      end;

      // Перевикидання оригінального винятку
      raise;
    end;
  end;
end;

procedure TChekDBManager.SaveConnectionState(out ChekPos, NDataPos: Integer);
begin
  ChekPos := 0;
  NDataPos := 0;

  if not FDataModule.QChekKOD.IsNull then
    ChekPos := FDataModule.QChekKOD.AsInteger;

  if not FDataModule.QNDataKOD.IsNull then
    NDataPos := FDataModule.QNDataKOD.AsInteger;

  Log(Format('Збережено позиції: Chek=%d, NData=%d', [ChekPos, NDataPos]));
end;

procedure TChekDBManager.RestoreConnectionState(ChekPos, NDataPos: Integer);
begin
  if ChekPos > 0 then
  begin
    if FDataModule.QChek.Locate('KOD', ChekPos, []) then
      Log(Format('✅ Позицію Chek відновлено: KOD=%d', [ChekPos]))
    else
      Log('⚠️ Не вдалося відновити позицію Chek');
  end;

  if NDataPos > 0 then
  begin
    if FDataModule.QNData.Locate('KOD', NDataPos, []) then
      Log(Format('✅ Позицію NData відновлено: KOD=%d', [NDataPos]))
    else
      Log('⚠️ Не вдалося відновити позицію NData');
  end;
end;

// Методи роботи з чеками
function TChekDBManager.CreateNewCheck(SchetID: Integer; IsFiscal: Boolean = True;
  PaymentTypeUI: string = 'Готівка'; PaymentSubTypeUI: string = '';
  const IBAN: string = ''; const RecipientName: string = '';
  const PaymentPurpose: string = ''; const ProviderType: string = '';
  Note: string = ''): Integer;
var
  FiscalStatus: string;
begin
  Result := 0;

  if SchetID <= 0 then
  begin
    Log('❌ Неможливо створити чек: невірний ID рахунку');
    Exit;
  end;

  // Валідація: для безготівкового обов'язково вказати підтип
  if (PaymentTypeUI = 'Безготівковий') and (PaymentSubTypeUI = '') then
  begin
    Log('❌ Для безготівкової оплати потрібно вказати підтип');
    Exit;
  end;

  // Перевірка, чи підтип є допустимим (якщо вказано)
  if (PaymentSubTypeUI <> '') and not IsValidSubType(PaymentSubTypeUI) then
  begin
    Log('❌ Невідомий підтип оплати: ' + PaymentSubTypeUI);
    Exit;
  end;

  if IsFiscal then
    FiscalStatus := FS_PENDING
  else
    FiscalStatus := FS_NON_FISCAL;

  SavPos;
  ClsCon;
  try
    // Параметризований запит
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'INSERT INTO CHEK (SCHET, SUMMA, DENGI, SDACHA, DOLG, PRIM, PRINTED, ' +
      'FISCAL_STATUS, PAYMENT_TYPE, PAYMENT_SUBTYPE, CASH_AMOUNT, CARD_AMOUNT, ' +
      'IBAN, RECIPIENT_NAME, PAYMENT_PURPOSE, CARD_MASK, AUTH_CODE, RRN, ' +
      'PROVIDER_TYPE, TERMINAL_ID, CREATED_AT) ' +
      'VALUES (:SCHET, 0, 0, 0, 0, :PRIM, 0, :FISCAL_STATUS, :PAYMENT_TYPE, :PAYMENT_SUBTYPE, ' +
      '0, 0, :IBAN, :RECIPIENT_NAME, :PAYMENT_PURPOSE, '''', '''', '''', :PROVIDER_TYPE, '''', CURRENT_TIMESTAMP)';

    FDataModule.SQLQ.ParamByName('SCHET').AsInteger := SchetID;
    FDataModule.SQLQ.ParamByName('PRIM').AsString := Note;
    FDataModule.SQLQ.ParamByName('FISCAL_STATUS').AsString := FiscalStatus;
    FDataModule.SQLQ.ParamByName('PAYMENT_TYPE').AsString := PaymentTypeUI;
    FDataModule.SQLQ.ParamByName('PAYMENT_SUBTYPE').AsString := PaymentSubTypeUI;
    FDataModule.SQLQ.ParamByName('IBAN').AsString := IBAN;
    FDataModule.SQLQ.ParamByName('RECIPIENT_NAME').AsString := RecipientName;
    FDataModule.SQLQ.ParamByName('PAYMENT_PURPOSE').AsString := PaymentPurpose;
    FDataModule.SQLQ.ParamByName('PROVIDER_TYPE').AsString := ProviderType;
    FDataModule.SQLQ.ExecSQL;

    // Отримуємо ID створеного чека
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text := 'SELECT MAX(KOD) as NEW_ID FROM CHEK WHERE SCHET = :SCHET';
    FDataModule.SQLQ.ParamByName('SCHET').AsInteger := SchetID;
    FDataModule.SQLQ.Open;
    Result := FDataModule.SQLQ.FieldByName('NEW_ID').AsInteger;
    FDataModule.SQLQ.Close;

    Log('✅ Чек створено успішно, ID: ' + IntToStr(Result) + ', фіскальний: ' + BoolToStr(IsFiscal, True));

  except
    on E: Exception do
    begin
      Log('❌ Помилка створення чека: ' + E.Message);
      Result := 0;
      // Спроба відновити з'єднання
      try
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text := 'SELECT 1 FROM CHEK WHERE 1=0';
        FDataModule.SQLQ.Open;
        FDataModule.SQLQ.Close;
        Log('✅ Зʼєднання з БД відновлено');
      except
        on E2: Exception do
          Log('❌ Не вдалося відновити зʼєднання з БД: ' + E2.Message);
      end;
    end;
  end;
  OpnCon;
  RstPos;
  if Result > 0 then FDataModule.QChek.Locate('KOD', Result, []);
end;

function TChekDBManager.DeleteCheck: Boolean;
var
  CheckID: Integer;
  HasProducts: Boolean;
  CheckNumberStr: string;
  CheckNumber, CheckNumberForLog: Integer;
  FiscalStatus: string;
begin
  Result := False;

  if FDataModule.QChekKOD.IsNull or (FDataModule.QChekKOD.AsInteger <= 0) then
  begin
    Log('❌ Неправильний ID чека для видалення');
    Exit;
  end;
  CheckID:=FDataModule.QChekKOD.AsInteger;
  // Отримуємо інформацію для логування
  if not GetCheckDetails(CheckID, CheckNumberForLog, FiscalStatus, HasProducts) then
  begin
    Log('❌ Не вдалося отримати інформацію про чек перед видаленням');
    Exit;
  end;

  // ✅ ВИПРАВЛЕННЯ: Викликаємо без зайвих параметрів
  if not CanDeleteCheck(CheckID) then
  begin
    Log('❌ Неможливо видалити чек ' + IntToStr(CheckID) +
        ' - фіскалізований або містить товари. ' +
        'Статус: ' + FiscalStatus + ', Товари: ' + BoolToStr(HasProducts, True));
    Exit;
  end;
  // Скасування номеру чека (тільки якщо номер існує)
  CancelCheckNumber(CheckID, FCurrentSchet);
  // Залишок коду без змін...
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.Close;

    // Видалення чека
    SafeExecSQL('DELETE FROM CHEK WHERE KOD = ' + IntToStr(CheckID));

    Result := True;
    Log('✅ Чек ' + IntToStr(CheckID) + ' видалено успішно');

  except
    on E: Exception do
    begin
      Log('❌ Помилка видалення чека: ' + E.Message);
      Result := False;
    end;
  end;
  OpnCon;
  //RstPos;
  FDataModule.QChek.Last;
end;

function TChekDBManager.CanDeleteCheck(CheckID: Integer): Boolean;
var
  CheckNumber: Integer;
  FiscalStatus: string;
  HasProducts: Boolean;
begin
  Result := False;

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для перевірки видалення');
    Exit;
  end;

  // Отримуємо всі деталі чека одним запитом
  if not GetCheckDetails(CheckID, CheckNumber, FiscalStatus, HasProducts) then
  begin
    Log('❌ Не вдалося отримати деталі чека для видалення');
    Exit;
  end;

  // Чек можна видалити тільки якщо:
  // 1. Не фіскалізований і не в процесі фіскалізації
  // 2. Не містить товарів
  Result := IsFiscalStatusModifiable(FiscalStatus) and not HasProducts;

  Log('Перевірка видалення чека ' + IntToStr(CheckID) +
      ': номер=' + IntToStr(CheckNumber) +
      ', статус=' + FiscalStatus +
      ', товари=' + BoolToStr(HasProducts, True) +
      ', можна_видалити=' + BoolToStr(Result, True));
end;


// Методи перевірки статусу чеків

function TChekDBManager.GetCheckFiscalStatus(CheckID: Integer): string;
begin
  Result := '';

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для отримання фіскального статусу');
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'SELECT FISCAL_STATUS FROM CHEK WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
      Result := FDataModule.SQLQ.FieldByName('FISCAL_STATUS').AsString;

    FDataModule.SQLQ.Close;

  finally
    OpnCon;
    RstPos;
  end;

  Log('Фіскальний статус чека ' + IntToStr(CheckID) + ': ' + Result);
end;

function TChekDBManager.IsCheckFiscalized(CheckID: Integer): Boolean;
var
  FiscalStatus: string;
begin
  Result := False;
  if CheckID <= 0 then Exit;

  FiscalStatus := GetCheckFiscalStatus(CheckID);
  Result := IsFiscalStatusDone(FiscalStatus);

  Log('Перевірка фіскалізації чека ' + IntToStr(CheckID) +
      ': статус=' + FiscalStatus + ', фіскалізований=' + BoolToStr(Result, True));
end;

function TChekDBManager.CanModifyCheck: Boolean;
var
  FiscalStatus: string;
  CheckID: Integer;
begin
  Result := False;
  if FDataModule.QChek.Active and (FDataModule.QChek.RecordCount > 0)
   then CheckID := FDataModule.QChek.FieldByName('KOD').AsInteger
   else
    begin
     Log('❌ Неправильний ID чека для перевірки модифікації');
     Exit;
    end;

  FiscalStatus := GetCheckFiscalStatus(CheckID);

  // Чек можна модифікувати тільки якщо він не фіскалізований і не в процесі фіскалізації
  Result := IsFiscalStatusModifiable(FiscalStatus);

  Log('Перевірка модифікації чека ' + IntToStr(CheckID) +
      ': статус=' + FiscalStatus + ', можна_модифікувати=' + BoolToStr(Result, True));
end;

function TChekDBManager.GetCheckDetails(CheckID: Integer; out CheckNumber: Integer; out FiscalStatus: string; out HasProducts: Boolean): Boolean;
begin
  Result := False;
  CheckNumber := 0;
  FiscalStatus := '';
  HasProducts := False;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'SELECT NOMER, FISCAL_STATUS FROM CHEK WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      // Правильна обробка NULL значень
      if not FDataModule.SQLQ.FieldByName('NOMER').IsNull then
        CheckNumber := FDataModule.SQLQ.FieldByName('NOMER').AsInteger
      else
        CheckNumber := 0;

      if not FDataModule.SQLQ.FieldByName('FISCAL_STATUS').IsNull then
        FiscalStatus := FDataModule.SQLQ.FieldByName('FISCAL_STATUS').AsString
      else
        FiscalStatus := '';

      FDataModule.SQLQ.Close;

      // Перевірка наявності товарів
      FDataModule.SQLQ.SQL.Text :=
        'SELECT COUNT(*) as CNT FROM NAK_DATA WHERE CHEK = :CHECK_ID';
      FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
      FDataModule.SQLQ.Open;
      HasProducts := FDataModule.SQLQ.FieldByName('CNT').AsInteger > 0;
      FDataModule.SQLQ.Close;

      Result := True;

      Log('✅ Отримано деталі чека ' + IntToStr(CheckID) +
          ': номер=' + IntToStr(CheckNumber) +
          ', статус=' + FiscalStatus +
          ', товари=' + BoolToStr(HasProducts, True));
    end
    else
    begin
      FDataModule.SQLQ.Close;
      Log('❌ Чек з ID ' + IntToStr(CheckID) + ' не знайдено');
    end;

  finally
    OpnCon;
    RstPos;
  end;
end;

// Методи конвертації чеків

procedure TChekDBManager.ConvertToNonFiscal(CheckID: Integer);
begin
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET FISCAL_STATUS = :STATUS, ' +
      'PRIM = ''КОНВЕРТОВАНО В СЛУЖБОВИЙ'' ' +
      'WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('STATUS').AsString := FS_NON_FISCAL;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

    Log('✅ Чек ' + IntToStr(CheckID) + ' конвертовано в службовий');
  finally
    OpnCon;
    RstPos;
  end;
end;

procedure TChekDBManager.ConvertToFiscal(CheckID: Integer);
begin
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
    'UPDATE CHEK SET FISCAL_STATUS = :STATUS, ' +
      'PRIM = ''КОНВЕРТОВАНО В ФІСКАЛЬНИЙ'' ' +
      'WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('STATUS').AsString := FS_PENDING;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

    Log('✅ Службовий чек ' + IntToStr(CheckID) + ' конвертовано в фіскальний');
  finally
    OpnCon;
    RstPos;
  end;
end;

// Методи роботи з товарами

procedure TChekDBManager.RemoveProductFromCheck(ProductDataID: Integer);
var
  ProductName: string;
  CheckID: Integer;
begin
  if ProductDataID <= 0 then
  begin
    Log('❌ Неправильний ID товару для видалення');
    Exit;
  end;

  // Отримуємо інформацію про товар для логування
  if GetProductInfo(ProductDataID, ProductName, CheckID) then
  begin
    Log('Спроба видалення товару: ' + ProductName + ' з чека ID: ' + IntToStr(CheckID));
  end;

  SavPos;
  ClsCon;
  try
    // Перевіряємо, чи активне з'єднання
    if not FDataModule.TrMag.Active then
      FDataModule.TrMag.StartTransaction;

    // Безпечне виконання SQL
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text := 'DELETE FROM NAK_DATA WHERE KOD = :PRODUCT_ID';
    FDataModule.SQLQ.ParamByName('PRODUCT_ID').AsInteger := ProductDataID;
    FDataModule.SQLQ.ExecSQL;

    // Комітимо зміни
    if FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;

    Log('✅ Товар видалено з БД: ' + ProductName + ' (ID: ' + IntToStr(ProductDataID) + ')');

  except
    on E: Exception do
    begin
      // Відкат у разі помилки
      if FDataModule.TrMag.Active then
        FDataModule.TrMag.Rollback;
      Log('❌ Помилка видалення товару з БД: ' + E.Message);
      raise; // Передаємо виняток далі
    end;
  end;

  OpnCon;
  RstPos;
end;


procedure TChekDBManager.UpdateProductInCheck;
var s:string;
begin

  if not CanModifyCheck then Exit;
  if (not DMMag.QChekKOD.IsNull) and (not FDataModule.QNDataKOD.IsNull) then
  begin
     FDataModule.SQLQ.Active:=false;
     FDataModule.SQLQ.SQL.Clear;
     FDataModule.SQLQ.SQL.Add('select KOL from OSTATKI_SKLADA where TOVAR='+FDataModule.QNDataTOVAR.AsString+' and OTDEL='+FDataModule.QNDataOTDEL.AsString);
     FDataModule.SQLQ.Active:=true;
     if not FDataModule.SQLQ.FieldByName('KOL').IsNull
      then FmNData.SpinEdit1.MaxValue:=FDataModule.SQLQ.FieldByName('KOL').AsInteger+FDataModule.QNDataKOL.AsInteger
      else FmNData.SpinEdit1.MaxValue:=FDataModule.QNDataKOL.AsInteger;
     FDataModule.SQLQ.Active:=false;

     FmNData.DateEdit1.Date:=FDataModule.QNDataDATA_VV.AsDateTime;
     FmNData.Label12.Caption:=FDataModule.QNDataNAZVA.AsString;
     FmNData.SpinEdit1.Value:=FDataModule.QNDataKOL.AsInteger;
     FmNData.FloatSpinEdit2.Value:=FDataModule.QNDataCENA.AsFloat;
     FmNData.Label5.Caption:=FDataModule.QNDataED.AsString;
     FmNData.pereschet;
     if FmNData.ShowModal=mrOk then
     begin
      SavPos;
      s:='update nak_data set data_vv='+
         #39+FormatDateTime('dd.mm.yyyy',Date)+#39+','+
         'kol='+FmNData.SpinEdit1.Text+','+
         'cena='+ #39 + FloatToStrF(round(FmNData.FloatSpinEdit2.Value*1000)/1000,ffGeneral,10,3,FDataModule.fmt) + #39 + ','+
         'summa='+FmNData.Label10.Caption+' '+
         'where kod='+inttostr(SavedNdataPos);
      ClsCon;
      FDataModule.LaunchQuery(FDataModule.SQLQ,FDataModule.TrMag,s);
      OpnCon;
      RstPos;
     end;
  end;
end;

function TChekDBManager.GetProductInfo(ProductDataID: Integer; out ProductName: string; out CheckID: Integer): Boolean;
begin
  Result := False;
  ProductName := '';
  CheckID := 0;

  if ProductDataID <= 0 then
  begin
    Log('❌ Неправильний ID товару для отримання інформації');
    Exit;
  end;

  // Перевіряємо, чи активне з'єднання
  if not FDataModule.TrMag.Active then
    FDataModule.TrMag.StartTransaction;

  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'SELECT nd.CHEK, t.NAZVA ' +
      'FROM NAK_DATA nd ' +
      'LEFT JOIN TOVAR t ON nd.TOVAR = t.KOD ' +
      'WHERE nd.KOD = :PRODUCT_ID';

    FDataModule.SQLQ.ParamByName('PRODUCT_ID').AsInteger := ProductDataID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      CheckID := FDataModule.SQLQ.FieldByName('CHEK').AsInteger;
      ProductName := FDataModule.SQLQ.FieldByName('NAZVA').AsString;
      Result := True;
    end;

    FDataModule.SQLQ.Close;

  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання інформації про товар: ' + E.Message);
      Result := False;
    end;
  end;
end;

// Методи фіскального статусу

procedure TChekDBManager.SetCheckFiscalStatus(CheckID: Integer; Status: string;
  FiscalData: string = ''; ErrorText: string = '');
begin
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET ' +
      'FISCAL_STATUS = :STATUS, ' +
      'FISCAL_RECEIPT_DATA = :FISCAL_DATA, ' +
      'FISCAL_ERROR_TEXT = :ERROR_TEXT, ' +
      'FISCAL_DATE = CASE WHEN :STATUS = ''' + FS_DONE + ''' THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END '+
      'WHERE KOD = :CHECK_ID';

    //FDataModule.SQLQ.ParamByName('DONE_STATUS').AsString := FS_DONE;
    FDataModule.SQLQ.ParamByName('STATUS').AsString := Status;
    FDataModule.SQLQ.ParamByName('FISCAL_DATA').AsString := FiscalData;
    FDataModule.SQLQ.ParamByName('ERROR_TEXT').AsString := ErrorText;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

  finally
    OpnCon;
    RstPos;
  end;

  Log('Оновлено фіскальний статус чека ' + IntToStr(CheckID) + ' на: ' + Status);
end;

procedure TChekDBManager.MarkCheckAsFiscalized(CheckID: Integer; FiscalCode: string;
  FiscalID: string; ShiftID: string; CashRegisterID: string);
begin
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET ' +
      'FISCAL_STATUS = :DONE_STATUS, ' +
      'FISCAL_CODE = :FISCAL_CODE, ' +
      'FISCAL_ID = :FISCAL_ID, ' +
      'SHIFT_ID = :SHIFT_ID, ' +
      'CASH_REGISTER_ID = :CASH_REGISTER_ID, ' +
      'FISCAL_DATE = CURRENT_TIMESTAMP, ' +
      'FISCAL_RETRY_COUNT = 0 ' +
      'WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('DONE_STATUS').AsString := FS_DONE;
    FDataModule.SQLQ.ParamByName('FISCAL_CODE').AsString := FiscalCode;
    FDataModule.SQLQ.ParamByName('FISCAL_ID').AsString := FiscalID;
    FDataModule.SQLQ.ParamByName('SHIFT_ID').AsString := ShiftID;
    FDataModule.SQLQ.ParamByName('CASH_REGISTER_ID').AsString := CashRegisterID;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

  finally
    OpnCon;
    RstPos;
  end;

  Log('Чек ' + IntToStr(CheckID) + ' позначено як зафіскалізований: ' + FiscalCode);
end;

procedure TChekDBManager.UpdateFiscalRetryCount(CheckID: Integer; RetryCount: Integer);
begin
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET FISCAL_RETRY_COUNT = :RETRY_COUNT WHERE KOD = :CHECK_ID';

    FDataModule.SQLQ.ParamByName('RETRY_COUNT').AsInteger := RetryCount;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

  finally
    OpnCon;
    RstPos;
  end;

  Log('Оновлено лічильник спроб для чека ' + IntToStr(CheckID) + ': ' + IntToStr(RetryCount));
end;

// Валідація та утиліти

function TChekDBManager.ValidateCheckIntegrity(CheckID: Integer): Boolean;
begin
  // Базова перевірка цілісності даних чека
  Result := (CheckID > 0) and FDataModule.QChek.Active;

  if Result then
    Log('Перевірка цілісності чека ' + IntToStr(CheckID) + ': OK')
  else
    Log('Перевірка цілісності чека ' + IntToStr(CheckID) + ': FAILED');
end;



function TChekDBManager.GetCurrentProductID: Integer;
begin
  if not FDataModule.QNDataKOD.IsNull then
    Result := FDataModule.QNDataKOD.AsInteger
  else
    Result := 0;
end;

function TChekDBManager.GetCurrentProductName: string;
begin
  if not FDataModule.QNDataNAZVA.IsNull then
    Result := FDataModule.QNDataNAZVA.AsString
  else
    Result := '';
end;
function TChekDBManager.GetNextCheckNumber(SchetID: Integer): Integer;
begin
  Result := 0;

  if SchetID <= 0 then
  begin
    Log('❌ Неправильний ID рахунку для отримання номеру чека');
    Exit;
  end;

  //SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'SELECT p.cheknomer ' +
      'FROM prodavec p, rekvizit r, schet s ' +
      'WHERE s.kod = ' + IntToStr(SchetID) +
      ' AND s.rekvizit = r.kod ' +
      'AND p.kod = r.prodavec';
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      // ✅ ВИПРАВЛЕННЯ: Без +1 тут
      Result := FDataModule.SQLQ.FieldByName('cheknomer').AsInteger;
      Log('✅ Отримано поточний номер чека: ' + IntToStr(Result));
    end
    else
    begin
      Log('Не вдалося отримати номер чека для рахунку з кодом:' + IntToStr(SchetID));
    end;

    FDataModule.SQLQ.Close;
  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання номеру чека: ' + E.Message);
      Result := 0;
    end;
  end;
  OpnCon;
  RstPos;
end;

procedure TChekDBManager.AssignCheckNumber(CheckID, CheckNumber, SchetID: Integer);
begin
  Log(Format('Спроба призначити номер чека: CheckID=%d, CheckNumber=%d, SchetID=%d',
    [CheckID, CheckNumber, SchetID]));

  if (CheckID <= 0) or (CheckNumber <= 0) or (SchetID <= 0) then
  begin
    Log(Format('❌ Неправильні параметри для призначення номеру чека: CheckID=%d, CheckNumber=%d, SchetID=%d',
      [CheckID, CheckNumber, SchetID]));
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    // Оновлення номеру в чеку
    SafeExecSQL('UPDATE chek SET nomer = ' + IntToStr(CheckNumber) +
                ' WHERE kod = ' + IntToStr(CheckID));

    // ВИПРАВЛЕННЯ: Використовуємо переданий SchetID замість FCurrentSchet
    SafeExecSQL('UPDATE prodavec SET cheknomer = ' + IntToStr(CheckNumber) +
                ' WHERE kod IN (SELECT p.kod FROM prodavec p, rekvizit r, schet s ' +
                'WHERE s.kod = ' + IntToStr(SchetID) +
                ' AND s.rekvizit = r.kod AND p.kod = r.prodavec)');

    Log('✅ Призначено номер чека ' + IntToStr(CheckNumber) +
        ' для чека ID: ' + IntToStr(CheckID) + ', рахунок: ' + IntToStr(SchetID));
  except
    on E: Exception do
    begin
      Log('❌ Помилка призначення номеру чека: ' + E.Message);
    end;
  end;
  OpnCon;
  RstPos;
end;


function TChekDBManager.GetProdavecID(SchetID: Integer): Integer;
begin
  Result := 0;

  if SchetID <= 0 then
  begin
    Log('❌ Неправильний ID рахунку для отримання продавця');
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'SELECT r.prodavec ' +
      'FROM rekvizit r, schet s ' +
      'WHERE s.kod = ' + IntToStr(SchetID) +
      ' AND s.rekvizit = r.kod';
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      Result := FDataModule.SQLQ.FieldByName('prodavec').AsInteger;
      Log('✅ Отримано ID продавця: ' + IntToStr(Result));
    end
    else
    begin
      Log('❌ Не вдалося отримати продавця для рахунку ' + IntToStr(SchetID));
    end;

    FDataModule.SQLQ.Close;
  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання ID продавця: ' + E.Message);
      Result := 0;
    end;
  end;
  OpnCon;
  RstPos;
end;

function TChekDBManager.GetLastCheckNumber(ProdavecID: Integer): Integer;
begin
  Result := 0;

  if ProdavecID <= 0 then
  begin
    Log('❌ Неправильний ID продавця для отримання останнього номера чека');
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'SELECT MAX(c.nomer) as max_nomer ' +
      'FROM chek c, rekvizit r, schet s ' +
      'WHERE s.kod = c.schet ' +
      'AND s.rekvizit = r.kod ' +
      'AND r.prodavec = ' + IntToStr(ProdavecID);
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      if not FDataModule.SQLQ.FieldByName('max_nomer').IsNull then
        Result := FDataModule.SQLQ.FieldByName('max_nomer').AsInteger;
      Log('✅ Отримано останній номер чека: ' + IntToStr(Result));
    end;

    FDataModule.SQLQ.Close;
  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання останнього номера чека: ' + E.Message);
      Result := 0;
    end;
  end;
  OpnCon;
  RstPos;
end;

procedure TChekDBManager.CancelCheckNumber(CheckID, SchetID: Integer);
var
  CurrentNumber, ProdavecID, LastNumber: Integer;
begin
  if (CheckID <= 0) or (SchetID <= 0) then
  begin
    Log('❌ Неправильні параметри для скасування номеру чека');
    Exit;
  end;

  // Отримуємо поточний номер чека
  CurrentNumber := 0;
  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text := 'SELECT nomer FROM chek WHERE kod = ' + IntToStr(CheckID);
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF and not FDataModule.SQLQ.FieldByName('nomer').IsNull then
      CurrentNumber := FDataModule.SQLQ.FieldByName('nomer').AsInteger;

    FDataModule.SQLQ.Close;
  finally
    OpnCon;
    RstPos;
  end;

  if CurrentNumber <= 0 then
  begin
    Log('❌ Чек не має номеру для скасування');
    Exit;
  end;

  // Отримуємо ID продавця
  ProdavecID := GetProdavecID(SchetID);
  if ProdavecID <= 0 then
  begin
    Log('❌ Не вдалося отримати продавця для скасування номеру чека');
    Exit;
  end;

  // Перевіряємо, чи це останній чек (опційно)
  LastNumber := GetLastCheckNumber(ProdavecID);
  if CurrentNumber <> LastNumber then
  begin
    Log('⚠️ Скасування не останнього чека: поточний=' + IntToStr(CurrentNumber) +
        ', останній=' + IntToStr(LastNumber));
    // Можна викинути виняток або показати повідомлення
  end;

  SavPos;
  ClsCon;
  try
    // Скасування номеру чека
    SafeExecSQL('UPDATE chek SET nomer = NULL WHERE kod = ' + IntToStr(CheckID));

    // Оновлення лічильника у продавця
    SafeExecSQL('UPDATE prodavec SET cheknomer = ' + IntToStr(CurrentNumber - 1) +
                ' WHERE kod IN (SELECT p.kod FROM prodavec p, rekvizit r, schet s ' +
                'WHERE s.kod = ' + IntToStr(SchetID) +
                ' AND s.rekvizit = r.kod AND p.kod = r.prodavec)');

    Log('✅ Скасовано номер чека ' + IntToStr(CurrentNumber) +
        ' для чека ID: ' + IntToStr(CheckID));
  except
    on E: Exception do
    begin
      Log('❌ Помилка скасування номеру чека: ' + E.Message);
    end;
  end;
  OpnCon;
  RstPos;
end;


function TChekDBManager.GetWarrantyProducts(CheckID, SchetID: Integer): TDataSet;
var
  SQLText: string;
begin
  Result := nil;

  if (CheckID <= 0) or (SchetID <= 0) then
  begin
    Log('❌ Неправильні параметри для отримання гарантійних товарів');
    Exit;
  end;

  try
    // Використовуємо DMMag.QGar замість FDataModule.SQLQ
    DMMag.QGar.Active := false;
    DMMag.QGar.SQL.Clear;

    SQLText :=
      'SELECT t.NAZVA, nd.KOL, ' +
      '(SELECT nazva FROM serijnik sn WHERE sn.NAK_DATA = nd.KOD) as SNAZVA ' +
      'FROM NAK_DATA nd, TOVAR t, SCHET sc ' +
      'WHERE sc.KOD = ' + IntToStr(SchetID) +
      ' AND nd.SCHET = sc.KOD ' +
      'AND nd.chek = ' + IntToStr(CheckID) +
      ' AND nd.TOVAR = t.kod ' +
      'AND nd.TIP = 1';

    DMMag.QGar.SQL.Text := SQLText;
    DMMag.QGar.Active := true;

    Result := DMMag.QGar;
    Log('✅ Отримано гарантійні товари для чека ID: ' + IntToStr(CheckID));

  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання гарантійних товарів: ' + E.Message);
      Result := nil;
    end;
  end;
end;

procedure TChekDBManager.CloseWarrantyDataSet;
begin
  try
    if FDataModule.SQLQ.Active then
      FDataModule.SQLQ.Close;
    Log('✅ Закрито DataSet гарантійних товарів');
  except
    on E: Exception do
      Log('❌ Помилка закриття DataSet: ' + E.Message);
  end;
end;

function TChekDBManager.CheckPrinting: Boolean;
var nch:integer;
    druk:boolean;
begin
  Result:=false;
  if FCurrentSchet <= 0 then Exit;
  if FDataModule.QChek.IsEmpty then Exit;
  if FDataModule.QNData.IsEmpty then
   begin
     Log('Помилка! Немає даних(товарів) для чека.');
     Exit;
   end;

  if FDataModule.QChekNOMER.IsNull then
  begin
    SavPos;
    ClsCon;

    // Використовуємо юніт для роботи з БД
    nch := GetNextCheckNumber(FCurrentSchet) + 1;
    if nch < 1 then nch := 1;

    FmChekno.SpinEdit1.Value := nch;
    FmChekno.Label1.Caption := pnazva;

    druk:=Fmchekno.ShowModal = mrOk;
    if druk then
    begin
      nch := FmChekno.SpinEdit1.Value;
      AssignCheckNumber(FDataModule.QChekKOD.AsInteger, nch, FCurrentSchet);
    end;

    OpnCon;
    RstPos;
    // Друк
    if druk then Result:=true;
  end;
end;

procedure TChekDBManager.UpdateFiscalStatus(CheckID: Integer; Status: string;
  FiscalData: string = ''; ErrorText: string = '');
begin
  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET ' +
      'FISCAL_STATUS = :STATUS, ' +
      'FISCAL_RECEIPT_DATA = :FISCAL_DATA, ' +
      'FISCAL_ERROR_TEXT = :ERROR_TEXT, ' +
      'FISCAL_DATE = CASE WHEN :STATUS = :DONE_STATUS THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END, ' +
      'FISCAL_RETRY_COUNT = CASE WHEN :STATUS = ''' + FS_ERROR + ''' THEN COALESCE(FISCAL_RETRY_COUNT, 0) + 1 ELSE FISCAL_RETRY_COUNT END ' +
      'WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('DONE_STATUS').AsString := FS_DONE;
    //FDataModule.SQLQ.ParamByName('ERROR_STATUS').AsString := FS_ERROR;
    FDataModule.SQLQ.ParamByName('STATUS').AsString := Status;
    FDataModule.SQLQ.ParamByName('FISCAL_DATA').AsString := FiscalData;
    FDataModule.SQLQ.ParamByName('ERROR_TEXT').AsString := ErrorText;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

    Log('Статус фіскалізації оновлено: ' + Status + ' для чека ' + IntToStr(CheckID));
  except
    on E: Exception do
      Log('Помилка оновлення статусу фіскалізації: ' + E.Message);
  end;
end;

procedure TChekDBManager.HandleFiscalizationException(ACheckID: Integer; E: Exception);
var
  WasInTransaction: Boolean;
begin
  WasInTransaction := FDataModule.TrMag.Active;

  if not WasInTransaction then
    FDataModule.TrMag.StartTransaction;

  try
    // Оновлення статусу помилки в БД
    UpdateFiscalStatusInDB(ACheckID,FS_ERROR, '', E.Message);

    // Оновлення тексту помилки через SQL (без QChek.Edit)
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET ' +
      'FISCAL_ERROR_TEXT = :ERROR_TEXT, ' +
      'FISCAL_RETRY_COUNT = COALESCE(FISCAL_RETRY_COUNT, 0) + 1 ' +
      'WHERE KOD = :CHECK_ID';

    FDataModule.SQLQ.ParamByName('ERROR_TEXT').AsString := E.Message;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := ACheckID;
    FDataModule.SQLQ.ExecSQL;

    if not WasInTransaction then
      FDataModule.TrMag.Commit;

    Log('Виняток фіскалізації оброблений для чека ' + IntToStr(ACheckID) + ': ' + E.Message);

  except
    on EDb: Exception do
    begin
      if not WasInTransaction then
        FDataModule.TrMag.Rollback;
      Log('Помилка в HandleFiscalizationException: ' + EDb.Message +
          ' (оригінальна помилка: ' + E.Message + ')');
    end;
  end;
end;


procedure TChekDBManager.UpdateFiscalStatusInDB(CheckID: Integer; Status: string;
  FiscalData: string = ''; ErrorText: string = ''; FiscalId: string = '';
  FiscalCode: string = ''; FiscalSerial: Integer = -1;
  ShiftId: string = ''; CashRegisterId: string = ''; RetryCount: Integer = -1);
var
  WasInTransaction: Boolean;
  CurrentCheckID: Integer; // Для збереження позиції
begin
  // Зберігаємо поточний ID
  if FDataModule.QChek.Active and (FDataModule.QChek.RecordCount > 0) then
    CurrentCheckID := FDataModule.QChek.FieldByName('KOD').AsInteger
  else
    CurrentCheckID := -1;

  WasInTransaction := FDataModule.TrMag.Active;
  if not WasInTransaction then
    FDataModule.TrMag.StartTransaction;

  Log(Format('UpdateFiscalStatusInDB: CheckID=%d, FiscalId=%s, FiscalCode=%s, ShiftId=%s, CashRegId=%s',
      [CheckID, FiscalId, FiscalCode, ShiftId, CashRegisterId]));

  try
    // Вимкнути оновлення візуальних компонентів
    FDataModule.QChek.DisableControls;
    FDataModule.QnData.DisableControls;
    FDataModule.QnSer.DisableControls;

    FDataModule.SQLQ.SQL.Text :=
    'UPDATE CHEK SET ' +
    'FISCAL_STATUS = :STATUS, ' +
    'FISCAL_RECEIPT_DATA = :FISCAL_DATA, ' +
    'FISCAL_ERROR_TEXT = :ERROR_TEXT, ' +
    'FISCAL_DATE = CASE WHEN :STATUS = ''' + FS_DONE + ''' THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END, ' +
    'FISCAL_RETRY_COUNT = :RETRY_COUNT, ' +
    'FISCAL_ID = :FISCAL_ID, ' +
    'FISCAL_CODE = :FISCAL_CODE, ' +
    'FISCAL_SERIAL = :FISCAL_SERIAL, ' +
    'SHIFT_ID = :SHIFT_ID, ' +
    'CASH_REGISTER_ID = :CASH_REGISTER_ID ' +
    'WHERE KOD = :CHECK_ID';

    if RetryCount = -1 then
      FDataModule.SQLQ.ParamByName('RETRY_COUNT').AsInteger := 0
    else
      FDataModule.SQLQ.ParamByName('RETRY_COUNT').AsInteger := RetryCount;

    //FDataModule.SQLQ.ParamByName('DONE_STATUS').AsString := FS_DONE;
    FDataModule.SQLQ.ParamByName('STATUS').AsString := Status;
    FDataModule.SQLQ.ParamByName('FISCAL_DATA').AsString := FiscalData;
    FDataModule.SQLQ.ParamByName('ERROR_TEXT').AsString := ErrorText;
    FDataModule.SQLQ.ParamByName('FISCAL_ID').AsString := FiscalId;
    FDataModule.SQLQ.ParamByName('FISCAL_CODE').AsString := FiscalCode;
    FDataModule.SQLQ.ParamByName('FISCAL_SERIAL').AsInteger := FiscalSerial;
    FDataModule.SQLQ.ParamByName('SHIFT_ID').AsString := ShiftId;
    FDataModule.SQLQ.ParamByName('CASH_REGISTER_ID').AsString := CashRegisterId;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;

    FDataModule.SQLQ.ExecSQL;

    if not WasInTransaction then
      FDataModule.TrMag.Commit;

    // ОНОВЛЕННЯ ДАНИХ В ГРИДІ
    RefreshDatasets(CurrentCheckID);
    //Log(Format('Успішно оновлено статус: %s для чека %d', [Status, CheckID]));
    Log(Format('Оновлено статус: %s для чека %d | Shift: %s | CashReg: %s',
        [Status, CheckID, Copy(ShiftId, 1, 8), Copy(CashRegisterId, 1, 8)]));

  except
    on E: Exception do
    begin
       // Увімкнути контроли навіть при помилці
      FDataModule.QChek.EnableControls;
      FDataModule.QnData.EnableControls;
      FDataModule.QnSer.EnableControls;

      if not WasInTransaction then
        FDataModule.TrMag.Rollback;
      Log('Помилка оновлення статусу: ' + E.Message);
      raise; // Прокидуємо помилку далі
    end;
  end;
end;

procedure TChekDBManager.MarkCheckAsPrinted(CheckID: Integer);
var
  s: string;
begin
  try
    SavPos;
    ClsCon;

    s := 'UPDATE CHEK SET PRINTED = 1 WHERE KOD = ' + IntToStr(CheckID);
    FDataModule.LaunchQuery(FDataModule.SQLQ, FDataModule.TrMag, s);

    OpnCon;
    RstPos;

    Log('Чек позначено як надрукований: ' + IntToStr(CheckID));
  except
    on E: Exception do
      Log('Помилка оновлення статусу друку: ' + E.Message);
  end;
end;


procedure TChekDBManager.RefreshDatasets(CurrentCheckID: Integer);
begin
  try
    // Оновлюємо datasets
    if FDataModule.QChek.Active then
    begin
      FDataModule.QChek.Close;
      FDataModule.QChek.Open;

      // Відновлюємо позицію
      if CurrentCheckID > 0 then
      begin
        if FDataModule.QChek.Locate('KOD', CurrentCheckID, []) then
          Log('Позицію відновлено')
        else
          Log('Не вдалося відновити позицію');
      end;
    end;

    // Оновлюємо пов'язані datasets
    if FDataModule.QnData.Active then
    begin
      FDataModule.QnData.Close;
      FDataModule.QnData.Open;
    end;

    if FDataModule.QnSer.Active then
    begin
      FDataModule.QnSer.Close;
      FDataModule.QnSer.Open;
    end;

  finally
    FDataModule.QChek.EnableControls;
    FDataModule.QnData.EnableControls;
    FDataModule.QnSer.EnableControls;
  end;
end;


procedure TChekDBManager.ValidateAndRepairCheckData(CheckID: Integer);
var TotalGoods: Double;
begin
  try
    // Перевірка активності запитів
    if not FDataModule.QChek.Active then
      FDataModule.QChek.Open;
    if not FDataModule.QNData.Active then
      FDataModule.QNData.Open;

    // Відновлення статусів після аварійного завершення
    if (FDataModule.QChekFISCAL_STATUS.AsString = FS_SENT) or
       (FDataModule.QChekFISCAL_STATUS.AsString = 'PROCESSING') then  // PROCESSING — старий артефакт
    begin
      Log('⚠️ Відновлення статусу чека після аварійного завершення');
      FDataModule.SQLQ.SQL.Text := 'UPDATE CHEK SET FISCAL_STATUS = :STATUS WHERE KOD = :CHECK_ID';
      FDataModule.SQLQ.ParamByName('STATUS').AsString := FS_PENDING;
      FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
      FDataModule.SQLQ.ExecSQL;
    end;

    // Синхронізація сум
    TotalGoods := 0.0;
    FDataModule.QNData.First;
    while not FDataModule.QNData.EOF do
    begin
      TotalGoods := TotalGoods + FDataModule.QNDataSUMMA.AsFloat;
      FDataModule.QNData.Next;
    end;

    // Оновлення суми в QChek якщо потрібно
    if Abs(FDataModule.QChekSUMMA.AsFloat - TotalGoods) > 0.01 then
    begin
      Log(Format('Відновлення суми чека: було %.2f, стало %.2f',
        [FDataModule.QChekSUMMA.AsFloat, TotalGoods]));
      FDataModule.SQLQ.SQL.Text := 'UPDATE CHEK SET SUMMA = :SUMMA WHERE KOD = :CHECK_ID';
      FDataModule.SQLQ.ParamByName('SUMMA').AsFloat := TotalGoods;
      FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
      FDataModule.SQLQ.ExecSQL;
    end;

  except
    on E: Exception do
      Log('❌ Помилка відновлення даних чека: ' + E.Message);
  end;
end;

// Оновлений метод оновлення оплати
procedure TChekDBManager.UpdatePaymentInfo(CheckID: Integer; PaymentTypeUI: string;
  CashAmount: Double; CardAmount: Double; PaymentSubTypeUI: string = '';
  const IBAN: string = ''; const RecipientName: string = '';
  const PaymentPurpose: string = ''; const CardMask: string = '';
  const AuthCode: string = ''; const RRN: string = '';
  const ProviderType: string = ''; const TerminalId: string = '');
begin
  // Валідація: для безготівкового обов'язково вказати підтип
  if (PaymentTypeUI = 'Безготівковий') and (PaymentSubTypeUI = '') then
  begin
    Log('❌ Для безготівкової оплати потрібно вказати підтип');
    raise Exception.Create('Для безготівкової оплати потрібно вказати підтип');
  end;

  // Перевірка, чи підтип є допустимим (якщо вказано)
  if (PaymentSubTypeUI <> '') and not IsValidSubType(PaymentSubTypeUI) then
  begin
    Log('❌ Невідомий підтип оплати: ' + PaymentSubTypeUI);
    raise Exception.Create('Невідомий підтип оплати: ' + PaymentSubTypeUI);
  end;

  try
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET ' +
      'PAYMENT_TYPE = :PAYMENT_TYPE, ' +
      'PAYMENT_SUBTYPE = :PAYMENT_SUBTYPE, ' +
      'CASH_AMOUNT = :CASH_AMOUNT, ' +
      'CARD_AMOUNT = :CARD_AMOUNT, ' +
      'IBAN = :IBAN, ' +
      'RECIPIENT_NAME = :RECIPIENT_NAME, ' +
      'PAYMENT_PURPOSE = :PAYMENT_PURPOSE, ' +
      'CARD_MASK = :CARD_MASK, ' +
      'AUTH_CODE = :AUTH_CODE, ' +
      'RRN = :RRN, ' +
      'PROVIDER_TYPE = :PROVIDER_TYPE, ' +
      'TERMINAL_ID = :TERMINAL_ID, ' +
      'UPDATED_AT = CURRENT_TIMESTAMP ' +
      'WHERE KOD = :CHECK_ID';

    FDataModule.SQLQ.ParamByName('PAYMENT_TYPE').AsString := PaymentTypeUI;
    FDataModule.SQLQ.ParamByName('PAYMENT_SUBTYPE').AsString := PaymentSubTypeUI;
    FDataModule.SQLQ.ParamByName('CASH_AMOUNT').AsFloat := CashAmount;
    FDataModule.SQLQ.ParamByName('CARD_AMOUNT').AsFloat := CardAmount;
    FDataModule.SQLQ.ParamByName('IBAN').AsString := IBAN;
    FDataModule.SQLQ.ParamByName('RECIPIENT_NAME').AsString := RecipientName;
    FDataModule.SQLQ.ParamByName('PAYMENT_PURPOSE').AsString := PaymentPurpose;
    FDataModule.SQLQ.ParamByName('CARD_MASK').AsString := CardMask;
    FDataModule.SQLQ.ParamByName('AUTH_CODE').AsString := AuthCode;
    FDataModule.SQLQ.ParamByName('RRN').AsString := RRN;
    FDataModule.SQLQ.ParamByName('PROVIDER_TYPE').AsString := ProviderType;
    FDataModule.SQLQ.ParamByName('TERMINAL_ID').AsString := TerminalId;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;

    FDataModule.SQLQ.ExecSQL;

    Log('Оновлено інформацію про оплату для чека ' + IntToStr(CheckID) +
        ': тип=' + PaymentTypeUI + ', підтип=' + PaymentSubTypeUI +
        ', готівка: ' + FloatToStrF(CashAmount, ffNumber, 10, 2) +
        ', картка: ' + FloatToStrF(CardAmount, ffNumber, 10, 2));

        // === ВИПРАВЛЕННЯ: оновлюємо живий датасет після прямого UPDATE ===
        if FDataModule.QChek.Active then
        begin
          // Найнадійніше — повне перевідкриття + позиціонування
          FDataModule.QChek.DisableControls;
          try
            FDataModule.QChek.Close;
            FDataModule.QChek.Open;
            if CheckID > 0 then
              FDataModule.QChek.Locate('KOD', CheckID, []);
          finally
            FDataModule.QChek.EnableControls;
          end;
        end;

  except
    on E: Exception do
      Log('Помилка оновлення інформації про оплату: ' + E.Message);
  end;
end;

procedure TChekDBManager.LogDatabaseState;
begin
  Log('=== СТАН БАЗИ ДАНИХ ===');
  Log('QChek активний: ' + BoolToStr(FDataModule.QChek.Active, True) +
      ', записів: ' + IntToStr(FDataModule.QChek.RecordCount));
  Log('QNData активний: ' + BoolToStr(FDataModule.QNData.Active, True) +
      ', записів: ' + IntToStr(FDataModule.QNData.RecordCount));
  Log('Транзакція активна: ' + BoolToStr(FDataModule.TrMag.Active, True));

  if not FDataModule.QChekKOD.IsNull then
    Log('Поточний чек: KOD=' + FDataModule.QChekKOD.AsString +
        ', NOMER=' + FDataModule.QChekNOMER.AsString);

  if not FDataModule.QNDataKOD.IsNull then
    Log('Поточний рядок: KOD=' + FDataModule.QNDataKOD.AsString +
        ', NAZVA=' + FDataModule.QNDataNAZVA.AsString);

  Log('========================');
end;

function TChekDBManager.AddProductToCheck: TAddProductResult;
var
  Ctx: TTransferContext;
  Res: TTransferResult;
  dalee: Boolean;
  CurrentPaymentType: string;
  CurrentSumma: Double;
  cur_schet, cur_chek: Integer;
begin
  Result := aprNone;

  if not CanModifyCheck then Exit;

  if FDataModule.QChekKod.IsNull or (CurrentSchet <= 0) then
  begin
    MessageDlg('Спочатку відкрийте новий чек!', mtWarning, [mbOk], 0);
    Exit;
  end;

  cur_schet := CurrentSchet;
  cur_chek  := FDataModule.QChekKOD.AsInteger;

  repeat
    FmOTov.OpenCon;
    if FmOTov.ShowModal = mrOk then
    begin
      FmNData.DateEdit1.Date := Date;
      FmNData.Label12.Caption := FDataModule.QOTNAZVA.AsString;
      FmNData.SpinEdit1.MaxValue := FDataModule.QOTKOL.AsInteger;
      FmNData.SpinEdit1.Value := 1;
      FmNData.FloatSpinEdit2.Value := FDataModule.QOTCENA.AsFloat;
      FmNData.Label5.Caption := FDataModule.QOTED.AsString;
      FmNData.pereschet;

      if FmNData.ShowModal = mrOk then
      begin
        dalee := True;
        SavPos;

        Ctx.DocID       := cur_schet;
        Ctx.IsCheck     := True;
        Ctx.CheckID     := cur_chek;
        Ctx.PrimPrefix  := 'чека';
        Ctx.SrcOtdel    := FDataModule.QOTOTDEL.AsInteger;
        Ctx.TovKod      := FDataModule.QOTTOVAR.AsInteger;
        Ctx.TovNazva    := FDataModule.QOTNAZVA.AsString;
        Ctx.TovEd       := FDataModule.QOTED.AsString;
        Ctx.TovCenaPrih := FDataModule.QOTCENA_PRIH.AsFloat;
        Ctx.TovTip      := FDataModule.QOTTIP.AsInteger;
        Ctx.Kol         := FmNData.SpinEdit1.Value;
        Ctx.Cena        := FmNData.FloatSpinEdit2.Value;
        Ctx.Summa       := FmNData.Label10.Caption;

        FmOTov.CloseCon;
        ClsCon;

        if AutoAddProductWithTransfer(Ctx, Res) then
        begin
          OpnCon;
          RstPos;
          FDataModule.QNData.Last;

          // Оновлення сум оплати (повний старий варіант)
          if not FDataModule.QChekKOD.IsNull then
          begin
            CurrentPaymentType := GetCurrentPaymentType;
            CurrentSumma := FDataModule.QChekSUMMA.AsFloat;

            if CurrentPaymentType = 'Готівка' then
            begin
              UpdatePaymentInfo(FDataModule.QChekKOD.AsInteger, 'Готівка',
                                CurrentSumma, 0, '');
              Log('💰 Оновлено CASH_AMOUNT після додавання товару, сума=' +
                  FloatToStrF(CurrentSumma, ffNumber, 10, 2));
            end
            else if CurrentPaymentType = 'Безготівковий' then
            begin
              UpdatePaymentInfo(FDataModule.QChekKOD.AsInteger, 'Безготівковий',
                                0, CurrentSumma,
                                FDataModule.QChekPAYMENT_SUBTYPE.AsString);
              Log('💳 Оновлено CARD_AMOUNT після додавання товару, сума=' +
                  FloatToStrF(CurrentSumma, ffNumber, 10, 2));
            end
            else
              Log('ℹ️ Тип оплати чека: ' + CurrentPaymentType +
                  ' — суми оплати не оновлено (змішаний/інший тип)');
          end;

          Result := aprAdded;

          if Res.NeedSerialSelect then
          begin
            VibSer;
            Result := aprNeedSerialSelect;
          end
          else if Res.NeedSerialsRemind then
          begin
            MessageDlg('Не забудьте вказати серійні номери.', mtInformation, [mbOk], 0);
            Result := aprNeedSerialsRemind;
          end;
        end
        else
        begin
          OpnCon;
          RstPos;
        end;
      end
      else
        dalee := False;
    end
    else
    begin
      dalee := False;
      FmOTov.CloseCon;
    end;
  until not dalee;

  if not FDataModule.QChek.Active then
  begin
    if FDataModule.TrMag.Active then FDataModule.TrMag.Commit;
    OpnCon;
  end;
  RstPos;
end;

procedure TChekDBManager.VibSer;
begin
 if
    (not FDataModule.QChekKOD.IsNull) and(not FDataModule.QNDataKOD.IsNull) then
 begin
    FDataModule.QOstSer.Active:=false;
    FDataModule.QOstSer.SQL.Clear;
    FDataModule.QOstSer.SQL.Add('select s.kod,s.nazva,s.prih_data,s.sklad,s.nak_data,pr.data_vv,ps.nazva as postav');
    FDataModule.QOstSer.SQL.Add('from serijnik s, prih_data p,prihod pr,postavshik ps');
    FDataModule.QOstSer.SQL.Add('where (s.nak_data is null) and s.sklad='+inttostr(FDataModule.otdel));
    FDataModule.QOstSer.SQL.Add(' and s.prih_data=p.kod and p.tovar='+FDataModule.QNDataTOVAR.AsString);
    FDataModule.QOstSer.SQL.Add(' and p.prihod=pr.kod and pr.postavshik=ps.kod');
    FDataModule.QOstSer.SQL.Add('order by data_vv,nazva');
    FDataModule.QOstSer.Active:=true;
    FmDGSer.Label1.Caption:=FDataModule.QNDataNAZVA.AsString;
    if (FmDGSer.showmodal=mrOk) and (FmDGSer.kod>0) then
    begin
     SavPos;
     ClsCon;
     FDataModule.LaunchQuery(FDataModule.SQLQ,FDataModule.TrMag,'update serijnik set nak_data='+inttostr(SavedNdataPos)+' where kod='+inttostr(FmDGSer.kod));
     OpnCon;
     RstPos;
    end;
    FDataModule.QOstSer.Active:=false;
 end
 else MessageDlg('Операція неможлива!',mtError,[mbOk],0);

end;

function TChekDBManager.LocateCheck(CheckID: Integer): Boolean;
begin
  Result := FDataModule.QChek.Locate('KOD', CheckID, []);
  if not Result then
    Log(Format('Чек %d не знайдено під час позиціонування', [CheckID]));
end;

function TChekDBManager.GetCheckTotal(CheckID: Integer): Double;
begin
  if LocateCheck(CheckID) then
    Result := FDataModule.QChekSUMMA.AsFloat
  else
  begin
    Result := 0;
    Log(Format('Не вдалося отримати суму для чека %d', [CheckID]));
  end;
end;

function TChekDBManager.GetCurrentPaymentType: string;
begin
  if FDataModule.QChek.Active and not FDataModule.QChek.IsEmpty then
    Result := FDataModule.QChek.FieldByName('PAYMENT_TYPE').AsString  // тепер українська назва
  else
    Result := '';
end;


function TChekDBManager.GetFiscalRetryCount(CheckID: Integer): Integer;
begin
  Result := 0;

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для отримання лічильника спроб');
    Exit;
  end;

  try
    // Перевіряємо, чи активне з'єднання
    if not FDataModule.TrMag.Active then
      FDataModule.TrMag.StartTransaction;

    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'SELECT COALESCE(FISCAL_RETRY_COUNT, 0) AS RETRY_COUNT ' +
      'FROM CHEK WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
      Result := FDataModule.SQLQ.FieldByName('RETRY_COUNT').AsInteger;

    FDataModule.SQLQ.Close;

    Log('Поточна кількість спроб для чека ' + IntToStr(CheckID) + ': ' + IntToStr(Result));

  except
    on E: Exception do
    begin
      Log('❌ Помилка отримання лічильника спроб: ' + E.Message);
      FDataModule.SQLQ.Close;
      Result := 0;
    end;
  end;
end;

procedure TChekDBManager.ResetFiscalRetryCount(CheckID: Integer);
begin
  SetFiscalRetryCount(CheckID, 0);
end;

procedure TChekDBManager.SetFiscalRetryCount(CheckID: Integer; RetryCount: Integer);
begin
  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для встановлення лічильника спроб');
    Exit;
  end;

  if RetryCount < 0 then
  begin
    Log('❌ Лічильник спроб не може бути від''ємним');
    Exit;
  end;

  try
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text :=
      'UPDATE CHEK SET FISCAL_RETRY_COUNT = :RETRY_COUNT WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('RETRY_COUNT').AsInteger := RetryCount;
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.ExecSQL;

    Log('✅ Лічильник спроб встановлено на ' + IntToStr(RetryCount) +
        ' для чека ' + IntToStr(CheckID));
  except
    on E: Exception do
    begin
      Log('❌ Помилка встановлення лічильника спроб: ' + E.Message);
    end;
  end;
end;

function TChekDBManager.ValidateCheckSums(CheckID: Integer;
  out TotalFromGoods, CheckSum: Double): Boolean;
var
  TotalFromGoodsCents: Int64;
  CheckSumCents: Int64;
begin
  Result := False;
  TotalFromGoods := 0.0;
  CheckSum := 0.0;
  TotalFromGoodsCents := 0;
  CheckSumCents := 0;

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека');
    Exit;
  end;

  try
    if not FDataModule.QNData.Active then
      FDataModule.QNData.Open;
    if not FDataModule.QChek.Active then
      FDataModule.QChek.Open;

    FDataModule.QNData.DisableControls;
    try
      FDataModule.QNData.First;
      while not FDataModule.QNData.EOF do
      begin
        TotalFromGoodsCents := TotalFromGoodsCents +
          Round(FDataModule.QNDataSUMMA.AsFloat * 100);
        FDataModule.QNData.Next;
      end;
    finally
      FDataModule.QNData.EnableControls;
    end;

    if FDataModule.QChek.Locate('KOD', CheckID, []) then
    begin
      CheckSumCents := Round(FDataModule.QChekSUMMA.AsFloat * 100);
    end
    else
    begin
      Log('❌ Чек ' + IntToStr(CheckID) + ' не знайдено');
      Exit;
    end;

    Result := Abs(TotalFromGoodsCents - CheckSumCents) <= 1;

    TotalFromGoods := TotalFromGoodsCents / 100;
    CheckSum := CheckSumCents / 100;

    if Result then
      Log(Format('✅ Суми збігаються: Товари=%.2f, Чек=%.2f',
        [TotalFromGoods, CheckSum]))
    else
      Log(Format('❌ НЕСПІВПАДІННЯ: Товари=%.2f, Чек=%.2f (різниця %d коп)',
        [TotalFromGoods, CheckSum, Abs(TotalFromGoodsCents - CheckSumCents)]));

  except
    on E: Exception do
    begin
      Log('❌ Помилка перевірки сум: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TChekDBManager.ValidateCheckForFiscalizationEx(CheckID: Integer;
  out ErrorMessage: string): Boolean;
var
  FiscalStatus: string;
  HasProducts: Boolean;
  CheckSumCents: Int64;
  TotalFromGoods: Double;
  CheckSumFromDB: Double;
begin
  Result := False;
  ErrorMessage := '';

  if CheckID <= 0 then
  begin
    ErrorMessage := 'Неправильний ID чека';
    Exit;
  end;

  try
    if not FDataModule.QChek.Active then
      FDataModule.QChek.Open;
    if not FDataModule.QNData.Active then
      FDataModule.QNData.Open;

    if not FDataModule.QChek.Locate('KOD', CheckID, []) then
    begin
      ErrorMessage := 'Чек не знайдено';
      Exit;
    end;

    if not FDataModule.QChekFISCAL_STATUS.IsNull then
      FiscalStatus := FDataModule.QChekFISCAL_STATUS.AsString
    else
      FiscalStatus := '';

    if FiscalStatus = FS_DONE then
    begin
      ErrorMessage := 'Чек вже фіскалізований (номер: ' + FDataModule.QChekFISCAL_CODE.AsString + ')';
      Exit;
    end;

    if FiscalStatus = FS_NON_FISCAL then
    begin
      ErrorMessage := 'Це службовий чек - фіскалізація не виконується';
      Exit;
    end;

    HasProducts := FDataModule.QNData.RecordCount > 0;
    if not HasProducts then
    begin
      ErrorMessage := 'Чек порожній! Додайте товари.';
      Exit;
    end;

    CheckSumCents := Round(FDataModule.QChekSUMMA.AsFloat * 100);
    if CheckSumCents <= 0 then
    begin
      ErrorMessage := 'Сума чека має бути більше 0!';
      Exit;
    end;

    if not ValidateCheckSums(CheckID, TotalFromGoods, CheckSumFromDB) then
    begin
      ErrorMessage := 'Неспівпадіння сум товарів і чека.';
      Exit;
    end;

    Result := True;
    Log('✅ Чек ' + IntToStr(CheckID) + ' готовий до фіскалізації');

  except
    on E: Exception do
    begin
      ErrorMessage := 'Помилка валідації: ' + E.Message;
      Log('❌ ' + ErrorMessage);
    end;
  end;
end;


function TChekDBManager.ClearSerialNumberAssignment: Boolean;
var
  SerialID: Integer;
begin
  Result := False;

  // Валідація стану даних
  if FDataModule.QChekKOD.IsNull then
  begin
    Log('❌ Немає активного чека для очищення привʼязки серійного номера');
    Exit;
  end;

  if FDataModule.QNDataKOD.IsNull then
  begin
    Log('❌ Немає активного рядка товару для очищення привʼязки серійного номера');
    Exit;
  end;

  if FDataModule.QNSerKOD.IsNull then
  begin
    Log('❌ Немає активного серійного номера для очищення привʼязки');
    Exit;
  end;

  SerialID := FDataModule.QNSerKOD.AsInteger;

  if SerialID <= 0 then
  begin
    Log('❌ Неправильний ID серійного номера: ' + IntToStr(SerialID));
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    try
      if not FDataModule.TrMag.Active then
        FDataModule.TrMag.StartTransaction;

      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE SERIJNIK SET NAK_DATA = NULL WHERE KOD = :SERIAL_ID';
      FDataModule.SQLQ.ParamByName('SERIAL_ID').AsInteger := SerialID;
      FDataModule.SQLQ.ExecSQL;

      if FDataModule.TrMag.Active then
        FDataModule.TrMag.Commit;

      Log('✅ Привʼязку серійного номера ' + IntToStr(SerialID) + ' очищено');
      Result := True;

    except
      on E: Exception do
      begin
        if FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('❌ Помилка очищення привʼязки серійного номера: ' + E.Message);
        raise;
      end;
    end;

  finally
    OpnCon;
    RstPos;
  end;
end;

// Допоміжна функція для конвертації старих типів (тимчасово)
function TChekDBManager.ConvertOldPaymentTypeToNew(const OldType: string; out NewTypeUI: string; out NewSubTypeUI: string): Boolean;
begin
  Result := True;
  if OldType = 'CASH' then
  begin
    NewTypeUI := 'Готівка';
    NewSubTypeUI := '';
  end
  else if OldType = 'CASHLESS' then
  begin
    NewTypeUI := 'Безготівковий';
    NewSubTypeUI := '';
  end
  else if OldType = 'MIXED' then
  begin
    NewTypeUI := 'Змішана';
    NewSubTypeUI := '';
  end
  else if OldType = 'OTHER' then
  begin
    NewTypeUI := 'Інше';
    NewSubTypeUI := '';
  end
  else
  begin
    Result := False;
    NewTypeUI := '';
    NewSubTypeUI := '';
  end;
end;

// Оновлений метод отримання деталей оплати
function TChekDBManager.GetPaymentDetails(CheckID: Integer; out Details: TPaymentDetails): Boolean;
begin
  Result := False;

  // Явна ініціалізація всіх полів замість FillChar
  Details.PaymentTypeUI := '';
  Details.SubTypeUI := '';
  Details.PaymentTypeCode := 0;
  Details.SubTypeCode := 0;
  Details.CashAmount := 0.0;
  Details.CardAmount := 0.0;
  Details.IBAN := '';
  Details.RecipientName := '';
  Details.PaymentPurpose := '';
  Details.CardMask := '';
  Details.AuthCode := '';
  Details.RRN := '';
  Details.ProviderType := '';
  Details.TerminalId := '';

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для отримання деталей оплати');
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'SELECT PAYMENT_TYPE, PAYMENT_SUBTYPE, PAYMENT_TYPE_I, PAYMENT_SUBTYPE_I, ' +
      'CASH_AMOUNT, CARD_AMOUNT, IBAN, RECIPIENT_NAME, PAYMENT_PURPOSE, ' +
      'CARD_MASK, AUTH_CODE, RRN, PROVIDER_TYPE, TERMINAL_ID ' +
      'FROM CHEK WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      Details.PaymentTypeUI := FDataModule.SQLQ.FieldByName('PAYMENT_TYPE').AsString;
      Details.SubTypeUI := FDataModule.SQLQ.FieldByName('PAYMENT_SUBTYPE').AsString;
      Details.PaymentTypeCode := FDataModule.SQLQ.FieldByName('PAYMENT_TYPE_I').AsInteger;
      Details.SubTypeCode := FDataModule.SQLQ.FieldByName('PAYMENT_SUBTYPE_I').AsInteger;
      Details.CashAmount := FDataModule.SQLQ.FieldByName('CASH_AMOUNT').AsFloat;
      Details.CardAmount := FDataModule.SQLQ.FieldByName('CARD_AMOUNT').AsFloat;
      Details.IBAN := FDataModule.SQLQ.FieldByName('IBAN').AsString;
      Details.RecipientName := FDataModule.SQLQ.FieldByName('RECIPIENT_NAME').AsString;
      Details.PaymentPurpose := FDataModule.SQLQ.FieldByName('PAYMENT_PURPOSE').AsString;
      Details.CardMask := FDataModule.SQLQ.FieldByName('CARD_MASK').AsString;
      Details.AuthCode := FDataModule.SQLQ.FieldByName('AUTH_CODE').AsString;
      Details.RRN := FDataModule.SQLQ.FieldByName('RRN').AsString;
      Details.ProviderType := FDataModule.SQLQ.FieldByName('PROVIDER_TYPE').AsString;
      Details.TerminalId := FDataModule.SQLQ.FieldByName('TERMINAL_ID').AsString;
      Result := True;
      Log('✅ Отримано деталі оплати для чека ' + IntToStr(CheckID));
    end
    else
    begin
      Log('❌ Чек ' + IntToStr(CheckID) + ' не знайдено при отриманні деталей оплати');
    end;

    FDataModule.SQLQ.Close;
  finally
    OpnCon;
    RstPos;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E1.2 — Offline-коди. ТЗ §3.3.                                                 }
{═══════════════════════════════════════════════════════════════════════════════}

{ INSERT нових кодів зі STATUS=0, PURPOSE=NULL, FISCAL_DATE=CURRENT_TIMESTAMP.
  Пропускає ті, що вже є (UNIQUE FISCAL_CODE). Повертає кількість вставлених. }
function TChekDBManager.SaveOfflineCodes(const ACodes: TOfflineCodeArray;
  const ACashierLogin: string): Integer;
var
  I, Inserted: Integer;
begin
  Result := 0;
  Inserted := 0;

  if Length(ACodes) = 0 then Exit;

  SavPos;
  ClsCon;
  try
    FDataModule.TrMag.StartTransaction;
    try
      for I := 0 to High(ACodes) do
      begin
        if Trim(ACodes[I].FiscalCode) = '' then Continue;

        // Пропускаємо вже існуючі
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'SELECT COUNT(*) AS CNT FROM CHEK_OFFLINE_FISCAL_CODES ' +
          'WHERE FISCAL_CODE = :FC';
        FDataModule.SQLQ.ParamByName('FC').AsString := ACodes[I].FiscalCode;
        FDataModule.SQLQ.Open;
        if FDataModule.SQLQ.FieldByName('CNT').AsInteger > 0 then
        begin
          FDataModule.SQLQ.Close;
          Continue;
        end;
        FDataModule.SQLQ.Close;

        // INSERT (ID згенерує тригер TR_CHEK_OFFLINE_FISCAL_CODES)
        FDataModule.SQLQ.SQL.Text :=
          'INSERT INTO CHEK_OFFLINE_FISCAL_CODES (' +
          '  CASH_REGISTER_ID, CASHIER_LOGIN, FISCAL_CODE, ' +
          '  STATUS, PURPOSE, FISCAL_DATE, CREATED_AT) ' +
          'VALUES (:CR, :CL, :FC, 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';
        FDataModule.SQLQ.ParamByName('CR').AsString := ACodes[I].CashRegisterID;
        FDataModule.SQLQ.ParamByName('CL').AsString := ACashierLogin;
        FDataModule.SQLQ.ParamByName('FC').AsString := ACodes[I].FiscalCode;
        FDataModule.SQLQ.ExecSQL;
        Inc(Inserted);
      end;

      FDataModule.TrMag.Commit;
    except
      FDataModule.TrMag.Rollback;
      raise;
    end;
  finally
    OpnCon;
    RstPos;
  end;

  Result := Inserted;
  Log(Format('SaveOfflineCodes: вставлено %d з %d (CR=%s)',
    [Inserted, Length(ACodes), Copy(ACodes[0].CashRegisterID, 1, 8) + '...']));
end;

{ Резервує 1 код: STATUS=0 → STATUS=1 + PURPOSE + RESERVED_AT.
  ТЗ §3.3: SELECT FIRST 1 ... FOR UPDATE WITH LOCK. }
function TChekDBManager.AllocateOfflineCode(const ACR, APurpose: string;
  out ACode: TOfflineCode): Boolean;
var
  Retry: Integer;
  Success: Boolean;
begin
  Result := False;
  ACode.ID := 0;
  ACode.FiscalCode := '';
  ACode.CashRegisterID := ACR;
  Success := False;

  for Retry := 1 to 3 do
  begin
    try
      SavPos;
      ClsCon;
      try
        FDataModule.TrMag.StartTransaction;
        try
          FDataModule.SQLQ.Close;
          FDataModule.SQLQ.SQL.Text :=
            'SELECT FIRST 1 ID, FISCAL_CODE FROM CHEK_OFFLINE_FISCAL_CODES ' +
            'WHERE CASH_REGISTER_ID = :CR AND STATUS = 0 ' +
            '  AND (PURPOSE IS NULL OR PURPOSE = :PU) ' +
            'ORDER BY CREATED_AT ' +
            'FOR UPDATE WITH LOCK';
          FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
          FDataModule.SQLQ.ParamByName('PU').AsString := APurpose;
          FDataModule.SQLQ.Open;

          if FDataModule.SQLQ.EOF then
          begin
            FDataModule.SQLQ.Close;
            FDataModule.TrMag.Commit;
            Log('AllocateOfflineCode: вільних кодів немає (CR=' +
                Copy(ACR, 1, 8) + '..., PURPOSE=' + APurpose + ')');
            Exit;
          end;

          ACode.ID := FDataModule.SQLQ.FieldByName('ID').AsInteger;
          ACode.FiscalCode := FDataModule.SQLQ.FieldByName('FISCAL_CODE').AsString;
          FDataModule.SQLQ.Close;

          FDataModule.SQLQ.SQL.Text :=
            'UPDATE CHEK_OFFLINE_FISCAL_CODES SET ' +
            '  STATUS = 1, PURPOSE = :PU, RESERVED_AT = CURRENT_TIMESTAMP ' +
            'WHERE ID = :ID AND STATUS = 0';
          FDataModule.SQLQ.ParamByName('PU').AsString := APurpose;
          FDataModule.SQLQ.ParamByName('ID').AsInteger := ACode.ID;
          FDataModule.SQLQ.ExecSQL;

          FDataModule.TrMag.Commit;
          Success := True;
        except
          FDataModule.TrMag.Rollback;
          raise;
        end;
      finally
        OpnCon;
        RstPos;
      end;
    except
      on E: Exception do
      begin
        Log(Format('AllocateOfflineCode: retry %d — %s', [Retry, E.Message]));
        if Retry >= 3 then
          raise;
        Sleep(100);
      end;
    end;

    if Success then Break;
  end;

  Result := Success;
  if Result then
    Log(Format('AllocateOfflineCode: RESERVED ID=%d FISCAL_CODE=%s PURPOSE=%s',
      [ACode.ID, ACode.FiscalCode, APurpose]));
end;

{ Рахує вільні коди. НЕ торкається чужої транзакції:
  якщо TrMag вже активна — використовує її; якщо ні — стартує й комітить свою. }
function TChekDBManager.CountFreeOfflineCodes(const ACR: string): Integer;
var
  WasActive: Boolean;
begin
  Result := 0;
  if ACR = '' then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT COUNT(*) AS CNT FROM CHEK_OFFLINE_FISCAL_CODES ' +
        'WHERE CASH_REGISTER_ID = :CR AND STATUS = 0';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.Open;
      if not FDataModule.SQLQ.EOF then
        Result := FDataModule.SQLQ.FieldByName('CNT').AsInteger;
      FDataModule.SQLQ.Close;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{ Рахує RESERVED-сироти (STATUS=1, CHECK_ID IS NULL). Аналогічний захист. }
function TChekDBManager.CountReservedOrphans(const ACR: string): Integer;
var
  WasActive: Boolean;
begin
  Result := 0;
  if ACR = '' then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT COUNT(*) AS CNT FROM CHEK_OFFLINE_FISCAL_CODES ' +
        'WHERE CASH_REGISTER_ID = :CR ' +
        '  AND STATUS = 1 AND CHECK_ID IS NULL';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.Open;
      if not FDataModule.SQLQ.EOF then
        Result := FDataModule.SQLQ.FieldByName('CNT').AsInteger;
      FDataModule.SQLQ.Close;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{ Скидає завислі RESERVED (CHECK_ID IS NULL, старші за 5 хв) → FREE.
  FISCAL_DATE не чіпаємо (ТЗ §3.3). }
function TChekDBManager.CleanupOrphanOfflineCodes(const ACR: string): Integer;
var
  Affected: Integer;
begin
  Result := 0;
  if ACR = '' then Exit;

  SavPos;
  ClsCon;
  try
    FDataModule.TrMag.StartTransaction;
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE CHEK_OFFLINE_FISCAL_CODES SET ' +
        '  STATUS = 0, PURPOSE = NULL, RESERVED_AT = NULL ' +
        'WHERE CASH_REGISTER_ID = :CR ' +
        '  AND STATUS = 1 ' +
        '  AND CHECK_ID IS NULL ' +
        '  AND (RESERVED_AT IS NULL OR ' +
        '       RESERVED_AT < DATEADD(-5 MINUTE TO CURRENT_TIMESTAMP))';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.ExecSQL;
      Affected := FDataModule.SQLQ.RowsAffected;
      FDataModule.TrMag.Commit;
      Result := Affected;
    except
      FDataModule.TrMag.Rollback;
      raise;
    end;
  finally
    OpnCon;
    RstPos;
  end;

  if Result > 0 then
    Log(Format('CleanupOrphanOfflineCodes: звільнено %d кодів (CR=%s)',
      [Result, Copy(ACR, 1, 8) + '...']));
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E2.1 — Збереження offline-продажу (атомарно).                                }
{  Код уже виділено у виклику (AllocateOfflineCode), тут лише:                  }
{    1) INSERT OFFLINE_RECEIPTS_QUEUE (STATUS=ОЧІКУЄ, LAST_RETRY_AT=NOW)         }
{    2) UPDATE CHEK.FISCAL_STATUS = ОЧІКУЄ                                       }
{    3) UPDATE CHEK_OFFLINE_FISCAL_CODES — прив'язка CHECK_ID + RECEIPT_UUID    }
{  На будь-якій помилці: Rollback + ReleaseReservedCode(ACode.ID).              }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.SaveOfflineSaleTransaction(
  ACheckID: Integer;
  const ACashRegisterID, ACashierLogin, AShiftID: string;
  const AReceiptUUID, AJsonString: string;
  const ACode: TOfflineCode;
  out AError: string): Boolean;
begin
  Result := False;
  AError := '';

  if ACheckID <= 0 then
  begin
    AError := 'Невірний CheckID';
    Exit;
  end;
  if ACashRegisterID = '' then
  begin
    AError := 'Не вказано CASH_REGISTER_ID';
    Exit;
  end;
  if ACode.ID <= 0 then
  begin
    AError := 'Не виділено offline-код (ACode.ID=0)';
    Exit;
  end;

  try
    SavPos;
    ClsCon;
    try
      FDataModule.TrMag.StartTransaction;
      try
        // 2a) INSERT у чергу
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'INSERT INTO OFFLINE_RECEIPTS_QUEUE (' +
          '  CHECK_ID, RECEIPT_UUID, RECEIPT_JSON, ERROR_MSG, ' +
          '  STATUS, RETRY_COUNT, CREATED_AT, LAST_RETRY_AT, ' +
          '  CASH_REGISTER_ID, CASHIER_LOGIN, SHIFT_ID, FISCAL_CODE) ' +
          'VALUES (' +
          '  :CHECK_ID, :RECEIPT_UUID, :RECEIPT_JSON, '''', ' +
          '  :STATUS, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ' +
          '  :CASH_REGISTER_ID, :CASHIER_LOGIN, :SHIFT_ID, :FISCAL_CODE)';
        FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger     := ACheckID;
        FDataModule.SQLQ.ParamByName('RECEIPT_UUID').AsString  := AReceiptUUID;
        FDataModule.SQLQ.ParamByName('RECEIPT_JSON').AsString  := AJsonString;
        FDataModule.SQLQ.ParamByName('STATUS').AsString        := FS_PENDING; // 'ОЧІКУЄ'
        FDataModule.SQLQ.ParamByName('CASH_REGISTER_ID').AsString := ACashRegisterID;
        FDataModule.SQLQ.ParamByName('CASHIER_LOGIN').AsString    := ACashierLogin;
        FDataModule.SQLQ.ParamByName('SHIFT_ID').AsString         := AShiftID;
        FDataModule.SQLQ.ParamByName('FISCAL_CODE').AsString      := ACode.FiscalCode;
        FDataModule.SQLQ.ExecSQL;

        // 2b) UPDATE CHEK → FISCAL_STATUS = ОЧІКУЄ
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE CHEK SET FISCAL_STATUS = :STATUS WHERE KOD = :CHECK_ID';
        FDataModule.SQLQ.ParamByName('STATUS').AsString   := FS_PENDING;
        FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := ACheckID;
        FDataModule.SQLQ.ExecSQL;

        // 2c) Прив'язка коду до чека (щоб CleanupOrphan не звільнив його)
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE CHEK_OFFLINE_FISCAL_CODES SET ' +
          '  CHECK_ID = :CHECK_ID, RECEIPT_UUID = :RECEIPT_UUID ' +
          'WHERE ID = :ID';
        FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger    := ACheckID;
        FDataModule.SQLQ.ParamByName('RECEIPT_UUID').AsString := AReceiptUUID;
        FDataModule.SQLQ.ParamByName('ID').AsInteger          := ACode.ID;
        FDataModule.SQLQ.ExecSQL;

        FDataModule.TrMag.Commit;
        Result := True;
      except
        if FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        raise;
      end;
    finally
      OpnCon;
      RstPos;
    end;
  except
    on E: Exception do
    begin
      AError := 'Помилка транзакції: ' + E.Message;
      Log('SaveOfflineSaleTransaction: ' + AError);
      // Звільнити код негайно (не чекаючи CleanupOrphanOfflineCodes - 5 хв)
      try
        ReleaseReservedCode(ACode.ID);
      except
        // ignore
      end;
    end;
  end;

  if Result then
    Log(Format('SaveOfflineSaleTransaction: OK CheckID=%d, Code=%s, UUID=%s, JSON=%d байт',
      [ACheckID, ACode.FiscalCode, AReceiptUUID, Length(AJsonString)]));
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  ReleaseReservedCode — примусове звільнення коду (без очікування 5 хв).       }
{═══════════════════════════════════════════════════════════════════════════════}
procedure TChekDBManager.ReleaseReservedCode(AID: Integer);
var
  WasActive: Boolean;
begin
  if AID <= 0 then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE CHEK_OFFLINE_FISCAL_CODES SET ' +
        '  STATUS = 0, PURPOSE = NULL, RESERVED_AT = NULL, ' +
        '  CHECK_ID = NULL, RECEIPT_UUID = NULL ' +
        'WHERE ID = :ID AND STATUS = 1';
      FDataModule.SQLQ.ParamByName('ID').AsInteger := AID;
      FDataModule.SQLQ.ExecSQL;
      Log(Format('ReleaseReservedCode: ID=%d звільнено', [AID]));
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('ReleaseReservedCode: ' + E.Message);
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E2.3 — Локальні ліміти 36 год (сесія) / 168 год (місяць). ТЗ §3.5.          }
{  Викликати ПЕРЕД offline-продажем і ПЕРЕД go-offline (E3).                   }
{  НЕ викликати перед sync. При помилці читання — НЕ блокуємо.                  }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.CheckOfflineLimits(const ACR: string;
  out AError: string): Boolean;
var
  IsOff, AccMin, WarnH, WarnM, CurSession, TotalMin: Integer;
  StartedAt: TDateTime;
  OffMonth: string;
  WasActive: Boolean;
begin
  Result := True;
  AError := '';
  if ACR = '' then Exit;

  WarnH := ReadWarnOfflineHours;   // clamp 1..36
  WarnM := ReadWarnMonthlyHours;   // clamp 1..168

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT IS_OFFLINE, OFFLINE_STARTED_AT, ACCUMULATED_MINUTES_MONTH, ' +
        '       OFFLINE_MONTH ' +
        'FROM CHEK_OFFLINE_STATE WHERE CASH_REGISTER_ID = :CR';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.Open;
      if FDataModule.SQLQ.EOF then
      begin
        FDataModule.SQLQ.Close;
        Exit; // немає стану — не offline, ліміти не перевищені
      end;

      IsOff := FDataModule.SQLQ.FieldByName('IS_OFFLINE').AsInteger;
      StartedAt := 0;
      if not FDataModule.SQLQ.FieldByName('OFFLINE_STARTED_AT').IsNull then
        StartedAt := FDataModule.SQLQ.FieldByName('OFFLINE_STARTED_AT').AsDateTime;
      if not FDataModule.SQLQ.FieldByName('ACCUMULATED_MINUTES_MONTH').IsNull then
        AccMin := FDataModule.SQLQ.FieldByName('ACCUMULATED_MINUTES_MONTH').AsInteger
      else
        AccMin := 0;
      if FDataModule.SQLQ.FieldByName('OFFLINE_MONTH').IsNull then
        OffMonth := ''
      else
        OffMonth := FDataModule.SQLQ.FieldByName('OFFLINE_MONTH').AsString;
      FDataModule.SQLQ.Close;

      // 36-годинний ліміт (поточна сесія)
      if (IsOff = 1) and (StartedAt > 0) then
      begin
        CurSession := MinutesBetween(Now, StartedAt);
        if CurSession >= WarnH * 60 then
        begin
          AError := Format(
            'Перевищено ліміт безперервної офлайн-сесії: %d хв ≥ %d год.' + sLineBreak +
            'Перейдіть в онлайн для синхронізації.',
            [CurSession, WarnH]);
          Exit(False);
        end;
      end;

      // 168-годинний ліміт (місяць)
      if OffMonth = FormatDateTime('yyyy-mm', Now) then
      begin
        TotalMin := AccMin;
        if (IsOff = 1) and (StartedAt > 0) then
          TotalMin := TotalMin + MinutesBetween(Now, StartedAt);
        if TotalMin >= WarnM * 60 then
        begin
          AError := Format(
            'Перевищено місячний ліміт офлайн: %d хв ≥ %d год.' + sLineBreak +
            'Офлайн-продаж заблоковано до наступного місяця.',
            [TotalMin, WarnM]);
          Exit(False);
        end;
      end;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        Log('CheckOfflineLimits: ' + E.Message);
        // При помилці — не блокуємо (safe default)
        Result := True;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E2.4 — Локальний offline-стан каси (читання з CHEK_OFFLINE_STATE).          }
{  Повертає False, якщо стану немає, помилка, або IS_OFFLINE <> 1.               }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.IsOfflineState(const ACR: string): Boolean;
var
  WasActive: Boolean;
begin
  Result := False;
  if ACR = '' then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT IS_OFFLINE FROM CHEK_OFFLINE_STATE WHERE CASH_REGISTER_ID = :CR';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.Open;
      if not FDataModule.SQLQ.EOF then
        Result := FDataModule.SQLQ.FieldByName('IS_OFFLINE').AsInteger = 1;
      FDataModule.SQLQ.Close;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        Log('IsOfflineState: ' + E.Message);
        Result := False;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.1 — UpdateOfflineStateStart: перевести касу в offline-стан.               }
{  UPSERT через окремі UPDATE/INSERT. Якщо рядка немає — INSERT з IS_OFFLINE=1.  }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.UpdateOfflineStateStart(const ACR: string;
  out AError: string): Boolean;
var
  Affected: Integer;
  OffMonth: string;
begin
  Result := False;
  AError := '';
  if ACR = '' then
  begin
    AError := 'CASH_REGISTER_ID порожній';
    Exit;
  end;

  OffMonth := FormatDateTime('yyyy-mm', Now);

  SavPos;
  ClsCon;
  try
    try
      FDataModule.TrMag.StartTransaction;
      try
        // 1) UPDATE, якщо рядок є
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE CHEK_OFFLINE_STATE SET ' +
          '  IS_OFFLINE = 1, ' +
          '  OFFLINE_STARTED_AT = CURRENT_TIMESTAMP, ' +
          '  OFFLINE_MONTH = :MON ' +
          'WHERE CASH_REGISTER_ID = :CR';
        FDataModule.SQLQ.ParamByName('MON').AsString := OffMonth;
        FDataModule.SQLQ.ParamByName('CR').AsString  := ACR;
        FDataModule.SQLQ.ExecSQL;
        Affected := FDataModule.SQLQ.RowsAffected;

        // 2) INSERT, якщо не було
        if Affected = 0 then
        begin
          FDataModule.SQLQ.Close;
          FDataModule.SQLQ.SQL.Text :=
            'INSERT INTO CHEK_OFFLINE_STATE (' +
            '  CASH_REGISTER_ID, IS_OFFLINE, OFFLINE_STARTED_AT, ' +
            '  ACCUMULATED_MINUTES_MONTH, OFFLINE_MONTH, LAST_OFFLINE_SEQ_NUMBER) ' +
            'VALUES (:CR, 1, CURRENT_TIMESTAMP, 0, :MON, 0)';
          FDataModule.SQLQ.ParamByName('CR').AsString  := ACR;
          FDataModule.SQLQ.ParamByName('MON').AsString := OffMonth;
          FDataModule.SQLQ.ExecSQL;
          Log('UpdateOfflineStateStart: INSERT новий рядок для CR=' + Copy(ACR, 1, 8) + '...');
        end
        else
          Log('UpdateOfflineStateStart: UPDATE існуючий рядок для CR=' + Copy(ACR, 1, 8) + '...');

        FDataModule.TrMag.Commit;
        Result := True;
      except
        if FDataModule.TrMag.Active then FDataModule.TrMag.Rollback;
        raise;
      end;
    except
      on E: Exception do
      begin
        AError := 'UpdateOfflineStateStart: ' + E.Message;
        Log(AError);
      end;
    end;
  finally
    OpnCon;
    RstPos;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.2 — UpdateOfflineStateStop: повернути касу в online-стан (після go-online). }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.UpdateOfflineStateStop(const ACR: string): Boolean;
begin
  Result := False;
  if ACR = '' then Exit;

  SavPos;
  ClsCon;
  try
    try
      FDataModule.TrMag.StartTransaction;
      try
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE CHEK_OFFLINE_STATE SET ' +
          '  IS_OFFLINE = 0, ' +
          '  OFFLINE_STARTED_AT = NULL, ' +
          '  LAST_ONLINE_AT = CURRENT_TIMESTAMP, ' +
          '  LAST_OFFLINE_SEQ_NUMBER = 0 ' +
          'WHERE CASH_REGISTER_ID = :CR';
        FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
        FDataModule.SQLQ.ExecSQL;
        FDataModule.TrMag.Commit;
        Result := True;
        Log('UpdateOfflineStateStop: IS_OFFLINE=0, seq=0 для CR=' + Copy(ACR, 1, 8) + '...');
      except
        if FDataModule.TrMag.Active then FDataModule.TrMag.Rollback;
        raise;
      end;
    except
      on E: Exception do
        Log('UpdateOfflineStateStop: ' + E.Message);
    end;
  finally
    OpnCon;
    RstPos;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.1 — CacheBalance: зберегти поточний баланс з API (гривні з копійками).   }
{  Оновлює BALANCE_CACHE, CASH_SALES_CACHE, CARD_SALES_CACHE.                  }
{═══════════════════════════════════════════════════════════════════════════════}
procedure TChekDBManager.CacheBalance(const ACR: string;
  ABalance, ACashSales, ACardSales: Double);
begin
  if ACR = '' then Exit;

  SavPos;
  ClsCon;
  try
    try
      FDataModule.TrMag.StartTransaction;
      try
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE CHEK_OFFLINE_STATE SET ' +
          '  BALANCE_CACHE = :BAL, ' +
          '  CASH_SALES_CACHE = :CASH, ' +
          '  CARD_SALES_CACHE = :CARD ' +
          'WHERE CASH_REGISTER_ID = :CR';
        FDataModule.SQLQ.ParamByName('BAL').AsFloat  := ABalance;
        FDataModule.SQLQ.ParamByName('CASH').AsFloat := ACashSales;
        FDataModule.SQLQ.ParamByName('CARD').AsFloat := ACardSales;
        FDataModule.SQLQ.ParamByName('CR').AsString  := ACR;
        FDataModule.SQLQ.ExecSQL;
        FDataModule.TrMag.Commit;
        Log(Format('CacheBalance: BAL=%.2f CASH=%.2f CARD=%.2f',
          [ABalance, ACashSales, ACardSales]));
      except
        if FDataModule.TrMag.Active then FDataModule.TrMag.Rollback;
        raise;
      end;
    except
      on E: Exception do
        Log('CacheBalance: ' + E.Message);
    end;
  finally
    OpnCon;
    RstPos;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.1 — LoadPendingQueue: читає чергу для каси у масив.                     }
{  Не тримає курсор між викликами. Тільки STATUS IN ('ОЧІКУЄ','ВІДПРАВЛЕНО').    }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.LoadPendingQueue(const ACR: string): TQueueItemArray;
var
  WasActive: Boolean;
begin
  SetLength(Result, 0);
  if ACR = '' then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT ID, CHECK_ID, RECEIPT_UUID, RECEIPT_JSON, FISCAL_CODE, ' +
        '       STATUS, LAST_RETRY_AT ' +
        'FROM OFFLINE_RECEIPTS_QUEUE ' +
        'WHERE CASH_REGISTER_ID = :CR ' +
        '  AND STATUS IN (:S1, :S2) ' +
        'ORDER BY ID';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.ParamByName('S1').AsString := QS_PENDING;
      FDataModule.SQLQ.ParamByName('S2').AsString := QS_SENT;
      FDataModule.SQLQ.Open;

      while not FDataModule.SQLQ.EOF do
      begin
        SetLength(Result, Length(Result) + 1);
        with Result[High(Result)] do
        begin
          ID          := FDataModule.SQLQ.FieldByName('ID').AsInteger;
          CheckID     := FDataModule.SQLQ.FieldByName('CHECK_ID').AsInteger;
          if not FDataModule.SQLQ.FieldByName('RECEIPT_UUID').IsNull then
            ReceiptUUID := FDataModule.SQLQ.FieldByName('RECEIPT_UUID').AsString
          else
            ReceiptUUID := '';
          ReceiptJSON := FDataModule.SQLQ.FieldByName('RECEIPT_JSON').AsString;
          if not FDataModule.SQLQ.FieldByName('FISCAL_CODE').IsNull then
            FIScalCode := FDataModule.SQLQ.FieldByName('FISCAL_CODE').AsString
          else
            FIScalCode := '';
          Status := FDataModule.SQLQ.FieldByName('STATUS').AsString;
          if not FDataModule.SQLQ.FieldByName('LAST_RETRY_AT').IsNull then
            LastRetryAt := FDataModule.SQLQ.FieldByName('LAST_RETRY_AT').AsDateTime
          else
            LastRetryAt := 0;
        end;
        FDataModule.SQLQ.Next;
      end;
      FDataModule.SQLQ.Close;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        Log('LoadPendingQueue: ' + E.Message);
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;

  Log(Format('LoadPendingQueue: %d pending (CR=%s)',
    [Length(Result), Copy(ACR, 1, 8) + '...']));
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.1 — SetQueueStatus: оновлює статус одного рядка черги.                  }
{═══════════════════════════════════════════════════════════════════════════════}
procedure TChekDBManager.SetQueueStatus(AQueueID: Integer;
  const AStatus, AError: string; ARetryDelta: Integer = 0);
var
  WasActive: Boolean;
begin
  if AQueueID <= 0 then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE OFFLINE_RECEIPTS_QUEUE SET ' +
        '  STATUS = :ST, ' +
        '  ERROR_MSG = :ERR, ' +
        '  LAST_RETRY_AT = CURRENT_TIMESTAMP, ' +
        '  RETRY_COUNT = COALESCE(RETRY_COUNT, 0) + :DELTA ' +
        'WHERE ID = :ID';
      FDataModule.SQLQ.ParamByName('ST').AsString    := AStatus;
      FDataModule.SQLQ.ParamByName('ERR').AsString   := Copy(AError, 1, 500);
      FDataModule.SQLQ.ParamByName('DELTA').AsInteger := ARetryDelta;
      FDataModule.SQLQ.ParamByName('ID').AsInteger   := AQueueID;
      FDataModule.SQLQ.ExecSQL;

      Log(Format('SetQueueStatus: ID=%d → %s (delta=%d)',
        [AQueueID, AStatus, ARetryDelta]));
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('SetQueueStatus: ' + E.Message);
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.1 — MarkSynced: атомарно позначає чек як синхронізований.               }
{  Оновлює три таблиці в одній транзакції.                                      }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.MarkSynced(AQueueID, ACheckID: Integer;
  const AFiscalCode, AFiscalID, AResponseJSON: string;
  out AError: string): Boolean;

begin
  Result := False;
  AError := '';
  if AQueueID <= 0 then
  begin
    AError := 'AQueueID=0';
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    try
      FDataModule.TrMag.StartTransaction;
      try
        // 1) Черга — СИНХРОНІЗОВАНО
        FDataModule.SQLQ.Close;
        FDataModule.SQLQ.SQL.Text :=
          'UPDATE OFFLINE_RECEIPTS_QUEUE SET ' +
          '  STATUS = :ST, ' +
          '  SYNCED_AT = CURRENT_TIMESTAMP, ' +
          '  FISCAL_RESPONSE = :RESP, ' +
          '  ERROR_MSG = '''' ' +
          'WHERE ID = :ID';
        FDataModule.SQLQ.ParamByName('ST').AsString   := QS_SYNCED;
        FDataModule.SQLQ.ParamByName('RESP').AsString := Copy(AResponseJSON, 1, 500);
        FDataModule.SQLQ.ParamByName('ID').AsInteger  := AQueueID;
        FDataModule.SQLQ.ExecSQL;

        // 2) CHEK — ФІСКАЛІЗОВАНО
        if ACheckID > 0 then
        begin
          FDataModule.SQLQ.Close;
          FDataModule.SQLQ.SQL.Text :=
            'UPDATE CHEK SET ' +
            '  FISCAL_STATUS = :ST, ' +
            '  FISCAL_CODE = :FC, ' +
            '  FISCAL_ID = :FID, ' +
            '  FISCAL_DATE = CURRENT_TIMESTAMP ' +
            'WHERE KOD = :ID';
          FDataModule.SQLQ.ParamByName('ST').AsString  := FS_DONE;
          FDataModule.SQLQ.ParamByName('FC').AsString  := AFiscalCode;
          FDataModule.SQLQ.ParamByName('FID').AsString := AFiscalID;
          FDataModule.SQLQ.ParamByName('ID').AsInteger := ACheckID;
          FDataModule.SQLQ.ExecSQL;
        end;

        // 3) Код — USED (знаходимо за FISCAL_CODE)
        if AFiscalCode <> '' then
        begin
          FDataModule.SQLQ.Close;
          FDataModule.SQLQ.SQL.Text :=
            'UPDATE CHEK_OFFLINE_FISCAL_CODES SET ' +
            '  STATUS = 2, USED_AT = CURRENT_TIMESTAMP ' +
            'WHERE FISCAL_CODE = :FC';
          FDataModule.SQLQ.ParamByName('FC').AsString := AFiscalCode;
          FDataModule.SQLQ.ExecSQL;
        end;

        FDataModule.TrMag.Commit;
        Result := True;
        Log(Format('MarkSynced: QueueID=%d CheckID=%d FC=%s → СИНХРОНІЗОВАНО',
          [AQueueID, ACheckID, AFiscalCode]));
      except
        if FDataModule.TrMag.Active then FDataModule.TrMag.Rollback;
        raise;
      end;
    except
      on E: Exception do
      begin
        AError := 'MarkSynced: ' + E.Message;
        Log(AError);
      end;
    end;
  finally
    OpnCon;
    RstPos;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.2 — TryAcquireLock: захопити lock для sync.                             }
{  Firebird не приймає параметр у DATEADD → обчислюємо :threshold у Pascal.     }
{  RowsAffected > 0 → lock наш. Інакше — хтось інший тримає.                    }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.TryAcquireLock(const ACR, AOwner: string;
  ATimeoutMin: Integer): Boolean;
var
  Threshold: TDateTime;
  WasActive: Boolean;
begin
  Result := False;
  if (ACR = '') or (AOwner = '') then Exit;
  if ATimeoutMin < 5  then ATimeoutMin := 5;
  if ATimeoutMin > 120 then ATimeoutMin := 120;

  Threshold := Now - (ATimeoutMin / MinsPerDay);

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE CHEK_OFFLINE_STATE SET ' +
        '  SYNC_LOCK_OWNER = :OWNER, ' +
        '  SYNC_LOCKED_AT = CURRENT_TIMESTAMP ' +
        'WHERE CASH_REGISTER_ID = :CR ' +
        '  AND (SYNC_LOCK_OWNER IS NULL OR SYNC_LOCKED_AT < :THRESHOLD)';
      FDataModule.SQLQ.ParamByName('OWNER').AsString := AOwner;
      FDataModule.SQLQ.ParamByName('CR').AsString    := ACR;
      FDataModule.SQLQ.ParamByName('THRESHOLD').AsDateTime := Threshold;
      FDataModule.SQLQ.ExecSQL;
      Result := FDataModule.SQLQ.RowsAffected > 0;

      if Result then
        Log('TryAcquireLock: ✅ отримано (owner=' + Copy(AOwner, 1, 16) +
            '..., timeout=' + IntToStr(ATimeoutMin) + ' хв)')
      else
        Log('TryAcquireLock: ❌ зайнято іншим власником');
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('TryAcquireLock: ' + E.Message);
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.2 — RefreshLock: heartbeat, оновлює SYNC_LOCKED_AT.                     }
{  Викликати з thread'а кожні ~2 хв (ТЗ §3.8).                                 }
{═══════════════════════════════════════════════════════════════════════════════}
procedure TChekDBManager.RefreshLock(const ACR, AOwner: string);
var
  WasActive: Boolean;
begin
  if (ACR = '') or (AOwner = '') then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE CHEK_OFFLINE_STATE SET ' +
        '  SYNC_LOCKED_AT = CURRENT_TIMESTAMP ' +
        'WHERE CASH_REGISTER_ID = :CR AND SYNC_LOCK_OWNER = :OWNER';
      FDataModule.SQLQ.ParamByName('CR').AsString    := ACR;
      FDataModule.SQLQ.ParamByName('OWNER').AsString := AOwner;
      FDataModule.SQLQ.ExecSQL;
      // Не логуємо кожен heartbeat (буде шумно). Можна увімкнути для дебагу.
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('RefreshLock: ' + E.Message);
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.2 — IsSyncLockOwner: чи ми досі власник lock.                            }
{  Викликати ПЕРЕД кожним POST у thread'і — якщо lock втрачено, зупиняємось.    }
{═══════════════════════════════════════════════════════════════════════════════}
function TChekDBManager.IsSyncLockOwner(const ACR, AOwner: string): Boolean;
var
  WasActive: Boolean;
begin
  Result := False;
  if (ACR = '') or (AOwner = '') then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'SELECT SYNC_LOCK_OWNER FROM CHEK_OFFLINE_STATE ' +
        'WHERE CASH_REGISTER_ID = :CR';
      FDataModule.SQLQ.ParamByName('CR').AsString := ACR;
      FDataModule.SQLQ.Open;
      if not FDataModule.SQLQ.EOF then
      begin
        if not FDataModule.SQLQ.FieldByName('SYNC_LOCK_OWNER').IsNull then
          Result := FDataModule.SQLQ.FieldByName('SYNC_LOCK_OWNER').AsString = AOwner;
      end;
      FDataModule.SQLQ.Close;
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('IsSyncLockOwner: ' + E.Message);
        Result := False;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;

{═══════════════════════════════════════════════════════════════════════════════}
{  E3.3.2 — ReleaseLock: звільнити lock (у finally thread'а).                    }
{═══════════════════════════════════════════════════════════════════════════════}
procedure TChekDBManager.ReleaseLock(const ACR, AOwner: string);
var
  WasActive: Boolean;
begin
  if (ACR = '') or (AOwner = '') then Exit;

  WasActive := FDataModule.TrMag.Active;
  if not WasActive then
    FDataModule.TrMag.StartTransaction;
  try
    try
      FDataModule.SQLQ.Close;
      FDataModule.SQLQ.SQL.Text :=
        'UPDATE CHEK_OFFLINE_STATE SET ' +
        '  SYNC_LOCK_OWNER = NULL, SYNC_LOCKED_AT = NULL ' +
        'WHERE CASH_REGISTER_ID = :CR AND SYNC_LOCK_OWNER = :OWNER';
      FDataModule.SQLQ.ParamByName('CR').AsString    := ACR;
      FDataModule.SQLQ.ParamByName('OWNER').AsString := AOwner;
      FDataModule.SQLQ.ExecSQL;
      if FDataModule.SQLQ.RowsAffected > 0 then
        Log('ReleaseLock: ✅ lock звільнено (owner=' + Copy(AOwner, 1, 16) + '...)');
    except
      on E: Exception do
      begin
        FDataModule.SQLQ.Close;
        if not WasActive and FDataModule.TrMag.Active then
          FDataModule.TrMag.Rollback;
        Log('ReleaseLock: ' + E.Message);
        raise;
      end;
    end;
  finally
    if not WasActive and FDataModule.TrMag.Active then
      FDataModule.TrMag.Commit;
  end;
end;


end.
