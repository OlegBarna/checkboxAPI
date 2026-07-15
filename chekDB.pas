unit chekdb;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, DataMod, chekno, Controls, Dialogs, DGSer, dndata, otov, sprop,chektypes;

type
  // Тип для процедури логування
  TLogProcedure = procedure(const AMessage: string) of object;

  // Record для збереження реквізитів оплати
  TPaymentDetails = record
    PaymentType: string;
    PaymentSubType: Integer;
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

  public
    datavv, nomer, psvid, nalkod, pnazva, pnazshort: string;  // Дані для звітів
    knazva:string; //назва клієнта для збереження чеків
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

    // Методи роботи з чеками
    function CreateNewCheck(SchetID: Integer; IsFiscal: Boolean = True;
      PaymentType: string = 'CASH'; PaymentSubType: Integer = 0;
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
    procedure AddProductToCheck;

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

    // Валідація та утиліти
    function ValidateCheckIntegrity(CheckID: Integer): Boolean;

    //function GetCurrentCheckID: Integer;
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
    procedure UpdatePaymentInfo(CheckID: Integer; PaymentType: string;
        CashAmount: Double; CardAmount: Double; PaymentSubType: Integer = 0;
        const IBAN: string = ''; const RecipientName: string = '';
        const PaymentPurpose: string = ''; const CardMask: string = '';
        const AuthCode: string = ''; const RRN: string = '';
        const ProviderType: string = ''; const TerminalId: string = '');
    procedure LogDatabaseState;

    function LocateCheck(CheckID: Integer): Boolean;
    function GetCheckTotal(CheckID: Integer): Double;
    function GetCurrentPaymentType: string;

    function ClearSerialNumberAssignment: Boolean;

    // Нові методи для роботи з оплатою
    function GetPaymentDetails(CheckID: Integer; out Details: TPaymentDetails): Boolean;
    function ConvertOldPaymentType(const OldType: string; out NewType: string;
      out SubType: Integer): Boolean;
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
  PaymentType: string = 'CASH'; PaymentSubType: Integer = 0;
  const IBAN: string = ''; const RecipientName: string = '';
  const PaymentPurpose: string = ''; const ProviderType: string = '';
  Note: string = ''): Integer;
var
  s, FiscalStatus: string;
begin
  Result := 0;

  if SchetID <= 0 then
  begin
    Log('❌ Неможливо створити чек: невірний ID рахунку');
    Exit;
  end;

  if IsFiscal then
    FiscalStatus := 'PENDING'
  else
    FiscalStatus := 'NON_FISCAL';

  s := 'insert into chek(schet,summa,dengi,sdacha,dolg,prim,printed,' +
       'fiscal_status, payment_type, payment_subtype, cash_amount, card_amount, ' +
       'iban, recipient_name, payment_purpose, card_mask, auth_code, rrn, ' +
       'provider_type, terminal_id, created_at) ' +
       'values(' + IntToStr(SchetID) + ',0,0,0,0,' +
       #39 + Note + #39 + ',' + '0,' +
       #39 + FiscalStatus + #39 + ',' +
       #39 + PaymentType + #39 + ',' +
       IntToStr(PaymentSubType) + ',' +
       '0,0,' +
       #39 + IBAN + #39 + ',' +
       #39 + RecipientName + #39 + ',' +
       #39 + PaymentPurpose + #39 + ',' +
       #39 + '' + #39 + ',' +  // CARD_MASK - порожній при створенні
       #39 + '' + #39 + ',' +  // AUTH_CODE
       #39 + '' + #39 + ',' +  // RRN
       #39 + ProviderType + #39 + ',' +
       #39 + '' + #39 + ',' +  // TERMINAL_ID - порожній при створенні
       'CURRENT_TIMESTAMP)';

  SavPos;
  ClsCon;
  try
    // Виконати запит
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text := s;
    FDataModule.SQLQ.ExecSQL;

    // Отримуємо ID створеного чека
    FDataModule.SQLQ.Close;
    FDataModule.SQLQ.SQL.Text := 'SELECT MAX(KOD) as NEW_ID FROM CHEK WHERE SCHET = ' + IntToStr(SchetID);
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
  Result := ((FiscalStatus = 'PENDING') or (FiscalStatus = '') or
            (FiscalStatus = 'NON_FISCAL') or (FiscalStatus.IsEmpty))
            and not HasProducts;

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
  Result := (FiscalStatus = 'DONE');

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
  Result := (FiscalStatus = 'PENDING') or (FiscalStatus = '') or
            (FiscalStatus = 'NON_FISCAL') or (FiscalStatus.IsEmpty);

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
      'UPDATE CHEK SET FISCAL_STATUS = ''NON_FISCAL'', ' +
      'PRIM = ''КОНВЕРТОВАНО В СЛУЖБОВИЙ'' ' +
      'WHERE KOD = :CHECK_ID';

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
      'UPDATE CHEK SET FISCAL_STATUS = ''PENDING'', ' +
      'PRIM = ''КОНВЕРТОВАНО В ФІСКАЛЬНИЙ'' ' +
      'WHERE KOD = :CHECK_ID';

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
      'FISCAL_DATE = CASE WHEN :STATUS = ''DONE'' THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END ' +
      'WHERE KOD = :CHECK_ID';

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
      'FISCAL_STATUS = ''DONE'', ' +
      'FISCAL_CODE = :FISCAL_CODE, ' +
      'FISCAL_ID = :FISCAL_ID, ' +
      'SHIFT_ID = :SHIFT_ID, ' +
      'CASH_REGISTER_ID = :CASH_REGISTER_ID, ' +
      'FISCAL_DATE = CURRENT_TIMESTAMP, ' +
      'FISCAL_RETRY_COUNT = 0 ' +
      'WHERE KOD = :CHECK_ID';

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
      'FISCAL_DATE = CASE WHEN :STATUS = ''DONE'' THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END, ' +
      'FISCAL_RETRY_COUNT = CASE WHEN :STATUS = ''ERROR'' THEN COALESCE(FISCAL_RETRY_COUNT, 0) + 1 ELSE FISCAL_RETRY_COUNT END ' +
      'WHERE KOD = :CHECK_ID';

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
    UpdateFiscalStatusInDB(ACheckID, 'ERROR', '', E.Message);

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
    'FISCAL_DATE = CASE WHEN :STATUS = ''DONE'' THEN CURRENT_TIMESTAMP ELSE FISCAL_DATE END, ' +
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
    if (FDataModule.QChekFISCAL_STATUS.AsString = 'SENT') or
       (FDataModule.QChekFISCAL_STATUS.AsString = 'PROCESSING') then
    begin
      Log('⚠️ Відновлення статусу чека після аварійного завершення');
      FDataModule.SQLQ.SQL.Text := 'UPDATE CHEK SET FISCAL_STATUS = ''NEW'' WHERE KOD = :CHECK_ID';
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

procedure TChekDBManager.UpdatePaymentInfo(CheckID: Integer; PaymentType: string;
  CashAmount: Double; CardAmount: Double; PaymentSubType: Integer = 0;
  const IBAN: string = ''; const RecipientName: string = '';
  const PaymentPurpose: string = ''; const CardMask: string = '';
  const AuthCode: string = ''; const RRN: string = '';
  const ProviderType: string = ''; const TerminalId: string = '');
begin
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

    FDataModule.SQLQ.ParamByName('PAYMENT_TYPE').AsString := PaymentType;
    FDataModule.SQLQ.ParamByName('PAYMENT_SUBTYPE').AsInteger := PaymentSubType;
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
        ': тип=' + PaymentType + ', підтип=' + IntToStr(PaymentSubType) +
        ', готівка: ' + FloatToStrF(CashAmount, ffNumber, 10, 2) +
        ', картка: ' + FloatToStrF(CardAmount, ffNumber, 10, 2));

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

procedure TChekDBManager.AddProductToCheck;
var
  s, z: string;
  dalee: boolean;
  zs, cs: integer;
  CurrentPaymentType: string;
  CurrentSumma: Double;
begin
  if not CanModifyCheck then Exit;
  if (not FDataModule.QChekKod.IsNull) and (CurrentSchet > 0) then
  begin
    repeat
      FmOTov.OpenCon;
      if FmOtov.ShowModal = mrOk then
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
          dalee := true;
          SavPos;
          s := 'insert into nak_data(chek,schet,data_vv,tovar,ed,kol,cena,cena_prih,summa,summa_prih,otdel,tip,cena_sklad) values(' +
               FDataModule.QChekKOD.AsString + ',' + inttostr(CurrentSchet) + ',' +
               #39 + FormatDateTime('dd.mm.yyyy', Date) + #39 + ',' +
               FDataModule.QOTTOVAR.AsString + ',' +
               #39 + FDataModule.QOTED.AsString + #39 + ',' +
               FmNData.SpinEdit1.Text + ',' +
               #39 + FloatToStrF(round(FmNData.FloatSpinEdit2.Value * 1000) / 1000, ffGeneral, 10, 3, FDataModule.fmt) + #39 + ',' +
               #39 + FloatToStrF(round(FDataModule.QOTCENA_PRIH.AsFloat * 100) / 100, ffGeneral, 10, 2, FDataModule.fmt) + #39 + ',' +
               FmNData.Label10.Caption + ',' +
               FmNData.SpinEdit1.Text + '*' + FloatToStrF(round(FDataModule.QOTCENA_PRIH.AsFloat * 100) / 100, ffGeneral, 10, 2, FDataModule.fmt) + ',' +
               FDataModule.QOTOTDEL.AsString + ',' +
               FDataModule.QOTTIP.AsString + ',' +
               #39 + FloatToStrF(round(FmNData.FloatSpinEdit2.Value * 1000) / 1000, ffGeneral, 10, 3, FDataModule.fmt) + #39 + ')';
          z := 'select count(s.kod) from serijnik s, prih_data p where (s.nak_data is null) and s.sklad=' + inttostr(FDataModule.otdel) +
               ' and s.prih_data=p.kod and p.tovar=' + FDataModule.QOTTOVAR.AsString;
          cs := FmNData.SpinEdit1.Value;
          FmOTov.CloseCon;
          ClsCon;
          FDataModule.LaunchQuery(FDataModule.SQLQ, FDataModule.TrMag, s);
          zs := FDataModule.Zapros('count', z);
          OpnCon;
          RstPos;
          FDataModule.QNData.Last;

          // Оновлення інформації про оплату після додавання товару
          // з урахуванням поточного типу оплати чека
          if not FDataModule.QChekKOD.IsNull then
          begin
            CurrentPaymentType := GetCurrentPaymentType;
            CurrentSumma := FDataModule.QChekSUMMA.AsFloat;

            if CurrentPaymentType = 'CASH' then
            begin
              UpdatePaymentInfo(FDataModule.QChekKOD.AsInteger, 'CASH',
                                CurrentSumma, 0);
              Log('💰 Оновлено CASH_AMOUNT після додавання товару, сума=' + FloatToStrF(CurrentSumma, ffNumber, 10, 2));
            end
            else if CurrentPaymentType = 'CASHLESS' then
            begin
              UpdatePaymentInfo(FDataModule.QChekKOD.AsInteger, 'CASHLESS',
                                0, CurrentSumma,
                                FDataModule.QChekPAYMENT_SUBTYPE.AsInteger);
              Log('💳 Оновлено CARD_AMOUNT після додавання товару, сума=' + FloatToStrF(CurrentSumma, ffNumber, 10, 2));
            end
            else
            begin
              // Для змішаної оплати або інших типів — залишаємо без змін
              Log('ℹ️ Тип оплати чека: ' + CurrentPaymentType + ' — суми оплати не оновлено (змішаний/інший тип)');
            end;
          end;

          if zs > 0 then
            if cs = 1 then
              VibSer
            else
              messagedlg('Не забудьте вказати серійні номери.', mtinformation, [mbok], 0);
        end
        else
          dalee := false;
      end
      else
      begin
        dalee := false;
        FmOTov.CloseCon;
      end;
    until not dalee;
  end
  else
    messagedlg('Спочатку відкрийте новий чек!', mtwarning, [mbok], 0);
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
    Result := FDataModule.QChek.FieldByName('PAYMENT_TYPE').AsString
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

    if FiscalStatus = 'DONE' then
    begin
      ErrorMessage := 'Чек вже фіскалізований (номер: ' +
        FDataModule.QChekFISCAL_CODE.AsString + ')';
      Exit;
    end;

    if FiscalStatus = 'NON_FISCAL' then
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

// Нові методи для роботи з оплатою

function TChekDBManager.GetPaymentDetails(CheckID: Integer; out Details: TPaymentDetails): Boolean;
begin
  Result := False;
  FillChar(Details, SizeOf(Details), 0);

  if CheckID <= 0 then
  begin
    Log('❌ Неправильний ID чека для отримання деталей оплати');
    Exit;
  end;

  SavPos;
  ClsCon;
  try
    FDataModule.SQLQ.SQL.Text :=
      'SELECT PAYMENT_TYPE, PAYMENT_SUBTYPE, CASH_AMOUNT, CARD_AMOUNT, ' +
      'IBAN, RECIPIENT_NAME, PAYMENT_PURPOSE, CARD_MASK, AUTH_CODE, RRN, ' +
      'PROVIDER_TYPE, TERMINAL_ID ' +
      'FROM CHEK WHERE KOD = :CHECK_ID';
    FDataModule.SQLQ.ParamByName('CHECK_ID').AsInteger := CheckID;
    FDataModule.SQLQ.Open;

    if not FDataModule.SQLQ.EOF then
    begin
      Details.PaymentType    := FDataModule.SQLQ.FieldByName('PAYMENT_TYPE').AsString;
      Details.PaymentSubType := FDataModule.SQLQ.FieldByName('PAYMENT_SUBTYPE').AsInteger;
      Details.CashAmount     := FDataModule.SQLQ.FieldByName('CASH_AMOUNT').AsFloat;
      Details.CardAmount     := FDataModule.SQLQ.FieldByName('CARD_AMOUNT').AsFloat;
      Details.IBAN           := FDataModule.SQLQ.FieldByName('IBAN').AsString;
      Details.RecipientName  := FDataModule.SQLQ.FieldByName('RECIPIENT_NAME').AsString;
      Details.PaymentPurpose := FDataModule.SQLQ.FieldByName('PAYMENT_PURPOSE').AsString;
      Details.CardMask       := FDataModule.SQLQ.FieldByName('CARD_MASK').AsString;
      Details.AuthCode       := FDataModule.SQLQ.FieldByName('AUTH_CODE').AsString;
      Details.RRN            := FDataModule.SQLQ.FieldByName('RRN').AsString;
      Details.ProviderType   := FDataModule.SQLQ.FieldByName('PROVIDER_TYPE').AsString;
      Details.TerminalId     := FDataModule.SQLQ.FieldByName('TERMINAL_ID').AsString;
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

function TChekDBManager.ConvertOldPaymentType(const OldType: string; out NewType: string;
  out SubType: Integer): Boolean;
begin
  Result := True;
  NewType := OldType;
  SubType := 0;

  if OldType = 'CASH' then
  begin
    NewType := 'CASH';
    SubType := 0;
    Log('Конвертація: CASH → CASH, підтип=0');
  end
  else if OldType = 'CARD' then
  begin
    NewType := 'CASHLESS';
    SubType := 1; // Картка
    Log('Конвертація: CARD → CASHLESS, підтип=1 (Картка)');
  end
  else if OldType = 'MIXED' then
  begin
    NewType := 'CASHLESS';
    SubType := 1; // Картка (з попередженням)
    Log('⚠️ Конвертація: MIXED → CASHLESS, підтип=1 (Картка). Увага: змішаний тип перетворено в картковий!');
  end
  else
  begin
    Result := False;
    Log('❌ Невідомий старий тип оплати: ' + OldType);
  end;
end;

end.
