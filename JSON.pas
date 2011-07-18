unit JSON;

// Written by IVO GELOV

// 16-Jul-2011  v1.1 - first public version

interface

uses SysUtils,Classes,Contnrs,Hashes;

Type
  TJSONtype = (jsNull, jsBool, jsInt, jsFloat, jsString, jsList, jsObject);

  TJSONError = class(Exception)
  end;

  TJSONarray = class;

  TJSONbase = Class (TObject)
  Protected
    FType:TJSONtype;
    FValue:Variant;
    FParent:TJSONarray;
    Function GetParent:TJSONarray; Virtual;
    Function GetType:TJSONtype; Virtual;
    Function GetValue:Variant; Virtual;
    procedure SetValue(AValue:Variant); Virtual;
    function GetJSON:AnsiString; Virtual;
    Procedure GetJSONBuf(st:TStringStream); Virtual;
    Function GetItem(Index:Integer):TJSONbase; Virtual;
    Procedure SetItem(Index:Integer;AValue:TJSONbase); Virtual;
    function GetField(const Key:WideString): TJSONbase; Virtual;
    procedure SetField(const Key:WideString;AValue:TJSONbase); Virtual;
    function GetName(Idx:Integer): WideString; Virtual;
    Function GetCount:Integer; Virtual;
  Public
    constructor Create(AParent:TJSONarray = Nil);
    Property Parent:TJSONarray read GetParent;
    Property SelfType:TJSONtype read GetType;
    Property Value:Variant Read GetValue write SetValue;
    Property JsonText:AnsiString Read GetJSON;
    Property Count:Integer read GetCount;
    Property Child[Idx:Integer]:TJSONbase Read GetItem Write SetItem;
    property Field[const Key:WideString]:TJSONbase Read GetField Write SetField;
    Property NameOf[Idx:Integer]:WideString Read GetName;
  End;

  TJSONIterator = procedure (ElName:WideString; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean);
  TJSONIteratorObj = procedure (ElName:WideString; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean) Of Object;
  TJSONlistIterator = procedure (Idx:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean);
  TJSONlistIteratorObj = procedure (Idx:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean) Of Object;

  TJSONarray = class(TJSONbase)
  Protected
    FItems:TObjectList;
    Function GetValue:Variant; Override;
    procedure SetValue(AValue:Variant); Override;
    Function GetItem(Index:Integer):TJSONbase; Override;
    Procedure SetItem(Index:Integer;AValue:TJSONbase); Override;
    Function GetCount:Integer; Override;
  Public
    constructor Create(AParent:TJSONarray = Nil);
    Destructor Destroy; Override;
  end;

  TJSONlist = class(TJSONarray)
  Protected
    Function GetType:TJSONtype; Override;
    Function GetJSON:AnsiString; Override;
    Procedure GetJSONBuf(st:TStringStream); Override;
    function GetField(const Key:WideString): TJSONbase; Override;
    procedure SetField(const Key:WideString;AValue:TJSONbase); Override;
    function GetName(Idx:Integer): WideString; Override;
  Public
    constructor Create(AParent:TJSONarray = Nil);
    Procedure Delete(Idx:Integer); Virtual;
    Procedure ForEach(Iterator:TJSONlistIterator;UserData:Pointer); Overload;
    Procedure ForEach(Iterator:TJSONlistIteratorObj;UserData:Pointer); Overload;

    procedure Add(B:Boolean); Overload;
    procedure Add(I:Int64); Overload;
    procedure Add(D:Double); Overload;
    procedure Add(S:WideString); Overload;
    procedure Add(A:TJSONbase); Overload;
  end;

  TJSONobject = class(TJSONarray)
  Protected
    FHash:TIntegerHash;
    FNames:TStringList;
    Function GetType:TJSONtype; Override;
    function GetField(const Key:WideString): TJSONbase; Override;
    procedure SetField(const Key:WideString;AValue:TJSONbase); Override;
    function GetName(Idx:Integer): WideString; Override;
    Function GetJSON:AnsiString; Override;
    Procedure GetJSONBuf(st:TStringStream); Override;
  Public
    constructor Create(AParent:TJSONarray = Nil);
    Destructor Destroy; Override;
    Procedure Delete(const Key:WideString);
    Procedure ForEach(Iterator:TJSONIterator;UserData:Pointer); Overload;
    Procedure ForEach(Iterator:TJSONIteratorObj;UserData:Pointer); Overload;

    procedure Add(Key:WideString;B:Boolean); Overload;
    procedure Add(Key:WideString;I:Int64); Overload;
    procedure Add(Key:WideString;D:Double); Overload;
    procedure Add(Key:WideString;S:WideString); Overload;
    procedure Add(Key:WideString;A:TJSONbase); Overload;
  End;

function ParseJSON(old_pos:PAnsiChar): TJSONarray;

Resourcestring
  JR_OBJ = 'Only TJSONlist or TJSONobject object can be assigned to TJSONbase';
  JR_TYPE = 'Invalid data type assigned to TJSONbase';
  JR_LIST_VALUE = 'TJSONlist does not have a value by itself - it is an indexed array';
  JR_LIST_NAME = 'TJSONlist use only Integer indexes - not String';
  JR_INDEX = 'Index (%d) is outside the array (%d)';
  JR_NO_INDEX = 'TJSONbase is not an array and does not support indexes';
  JR_NO_NAME = 'Associative arrays does not support empty index';
  JR_OBJ_VALUE = 'TJSONobject does not have a value by itself - it is an indexed array';
  JR_BAD_TXT = 'Unsupported data type in TJSONbase.Text';
  JR_NO_COUNT = 'TJSONbase is not an array and does not have Count property';
  JR_PARSE_CHAR = 'Unexpected character at position %d';
  JR_PARSE_EMPTY = 'Empty element at position %d';
  JR_OPEN_LIST = 'Missing closing ]';
  JR_OPEN_STRING = 'Unterminated string at position %d';
  JR_NO_COLON = 'Missing property name/value delimiter (:) at position %d';
  JR_NO_VALUE = 'Missing property value at position %d';
  JR_BAD_FLOAT = 'Missing fractional part of a floating-point number at position %d';
  JR_BAD_EXPONENT = 'Exponent of the number is not integer at position %d';
  JR_UNQUOTED = 'Unquoted property name at position %d';
  JR_CONTROL = 'Control character (%d) encountered at position %d in %s';
  JR_ESCAPE = 'Unrecognized escape sequence at position %d in "%s"';
  JR_CODEPOINT = 'Invalid UNICODE escape sequence at position %d in "%s"';
  JR_UNESCAPED = 'Unescaped symbol at position %d in "%s"';
  JR_EMPTY_NAME = 'Empty property name at position %d';

implementation

uses Windows,Variants;

Var
  fmt:TFormatSettings;

Function EscapeString(const s:WideString):AnsiString;
var
  i:Integer;
Begin
  Result:='"';
  For i:=1 to Length(s) do
    Case s[i] Of
      '/', '\', '"': Result:=Result + '\' + s[i];
      #8: Result:=Result+'\b';
      #9: Result:=Result+'\t';
      #10:Result:=Result+'\n';
      #12:Result:=Result+'\f';
      #13:Result:=Result+'\r';
    Else
      if s[i] in [WideChar(' ') .. WideChar('~')] Then Result:=Result + s[i]
        else Result:=Result + '\u' + IntToHex(Ord(s[i]),4)
    end;
  Result:=Result+'"';
end;

Function UnescapeString(const s:AnsiString):WideString;
var
  W:WideString;
  i,j,k,Len:Integer;
  code:string[5];
Begin
  code:='$    ';
  Len:=Length(s);
  SetLength(W,Len);
  i:=1;
  j:=0;
  While i<=Len do
  begin
    if s[i] < ' ' then Raise TJSONError.CreateFmt(JR_CONTROL,[Ord(s[i]),i,s]);
    If s[i] = '\' Then
    Begin
      Inc(i);
      case s[i] Of
        '"','\','/':
          Begin
            Inc(j);
            W[j]:=WideChar(s[i]);
            Inc(i);
          end;
        'b':
          Begin
            Inc(j);
            W[j]:=#8;
            Inc(i);
          end;
        't':
          Begin
            Inc(j);
            W[j]:=#9;
            Inc(i);
          end;
        'n':
          Begin
            Inc(j);
            W[j]:=#10;
            Inc(i);
          end;
        'f':
          Begin
            Inc(j);
            W[j]:=#12;
            Inc(i);
          end;
        'r':
          Begin
            Inc(j);
            W[j]:=#13;
            Inc(i);
          end;
        'u':
          Begin
            if i+4 > Len Then
              raise TJSONError.CreateFmt(JR_CODEPOINT,[i,s]);
            For k:=1 to 4 do
              If Not (s[i+k] in ['0'..'9','a'..'f','A'..'F']) then
                Raise TJSONError.CreateFmt(JR_CODEPOINT,[i,s])
              Else code[k+1]:=s[i+k];
            Inc(j);
            Inc(i,5);
            W[j]:=WideChar(StrToInt(code));
          end;
      Else
        Raise TJSONError.CreateFmt(JR_ESCAPE,[i,s]);
      end;
    end
    else
    Begin
      if not (s[i] in [#32..#126]) then Raise TJSONError.CreateFmt(JR_UNESCAPED,[i,s]);
      Inc(j);
      W[j]:=WideChar(s[i]);
      Inc(i);
    end;
  End;
  // now J contains the real length of W in characters
  Result:=Copy(W,1,J);
end;

// ===== TJSONbase =====

Constructor TJSONbase.Create(AParent:TJSONarray);
Begin
  FType:=jsNull;
  FValue:=Null;
  FParent:=AParent;
end;

Function TJSONbase.GetParent:TJSONarray;
Begin
  Result:=FParent;
end;

Function TJSONbase.GetType:TJSONtype;
Begin
  Result:=FType;
end;

Function TJSONbase.GetValue:Variant;
Begin
  Result:=FValue;
end;

Procedure TJSONbase.SetValue (AValue:Variant);
Begin
  // clear previous value
  Case VarType(AValue) Of
    varEmpty,
    varNull:
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsNull;
        FValue:=Null;
      end;
    varBoolean:
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsBool;
        FValue:=AValue;
      end;
    varShortInt,
    varByte,
    varSmallint,
    varWord,
    varInteger,
    varLongWord,
    varInt64:
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsInt;
        FValue:=AValue;
      end;
    varCurrency,
    varSingle,
    varDouble:
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsFloat;
        FValue:=AValue;
      end;
    varOleStr,
    varStrArg,
    varString:
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsString;
        FValue:=AValue;
      end;
    varByRef:
      if TObject(TVarData(AValue).VPointer) is TJSONlist Then
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsList;
        FValue:=AValue;
      end
      else if TObject(TVarData(AValue).VPointer) is TJSONobject Then
      Begin
        if FType In [jsList, jsObject] then FValue.Free;
        FType:=jsObject;
        FValue:=AValue;
      end
      else Raise TJSONError.Create(JR_OBJ);
  else Raise TJSONError.Create(JR_TYPE);
  end;
end;

Function TJSONbase.GetJSON:AnsiString;
Begin
  Case FType Of
    jsNull:   Result:='null';
    jsBool:   if FValue then Result:='true' else Result:='false';
    jsInt:    Result:=IntToStr(FValue);
    jsFloat:  Result:=Format('%g',[Double(FValue)],fmt);
    jsString: Result:=EscapeString(FValue);
  Else raise TJSONError.Create(JR_BAD_TXT);
  end;
end;

Procedure TJSONbase.GetJSONBuf(st:TStringStream);
Begin
  st.WriteString(GetJSON);
end;

Function TJSONbase.GetCount:Integer;
Begin
  Raise TJSONError.Create(JR_NO_COUNT);
end;

Function TJSONbase.GetItem(Index:Integer):TJSONbase;
Begin
  Raise TJSONError.Create(JR_NO_INDEX);
end;

procedure TJSONbase.SetItem(Index:Integer;AValue:TJSONbase);
Begin
  Raise TJSONError.Create(JR_NO_INDEX);
end;

function TJSONbase.GetField(const Key:WideString):TJSONbase;
Begin
  Raise TJSONError.Create(JR_NO_INDEX);
end;

procedure TJSONbase.SetField(const Key:WideString; AValue:TJSONbase);
Begin
  Raise TJSONError.Create(JR_NO_INDEX);
end;

function TJSONbase.GetName(Idx:Integer):WideString;
Begin
  Raise TJSONError.Create(JR_NO_INDEX);
end;

// ===== TJSONlist =====

Constructor TJSONarray.Create(AParent:TJSONarray);
Begin
  Inherited;
  FItems:=TObjectList.Create;
  FItems.Capacity:=8;
end;

Destructor TJSONarray.Destroy;
Begin
  FItems.Free;
  Inherited;
end;

Function TJSONarray.GetItem(Index:Integer):TJSONbase;
Begin
  if (Index>=0)and(Index<FItems.Count) Then Result:=Pointer(FItems[Index])
    else Result:=Nil;
end;

Procedure TJSONarray.SetItem(Index:Integer;AValue:TJSONbase);
Begin
  if (Index>=0)and(Index<FItems.Count) Then FItems[Index]:=AValue
    else Raise TJSONError.CreateFmt(JR_INDEX,[Index,FItems.Count]);
end;

Function TJSONarray.GetCount:Integer;
Begin
  Result:=FItems.Count;
end;

Function TJSONarray.GetValue:Variant;
Begin
  Raise TJSONError.Create(JR_LIST_VALUE);
end;

procedure TJSONarray.SetValue(AValue:Variant);
Begin
  Raise TJSONError.Create(JR_LIST_VALUE);
end;

// ===== TJSONlist =====

Constructor TJSONlist.Create(AParent:TJSONarray);
Begin
  Inherited;
  FType:=jsList;
end;

Function TJSONlist.GetType:TJSONtype;
Begin
  Result:=jsList;
end;

procedure TJSONlist.Delete(Idx:Integer);
Begin
  if (Idx>=0)and(Idx<FItems.Count) Then FItems.Delete(Idx)
    else Raise TJSONError.CreateFmt(JR_INDEX,[Idx,FItems.Count]);
end;

Procedure TJSONlist.ForEach(Iterator:TJSONlistIterator;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
Begin
  i:=0;
  stop:=False;
  while (i<FItems.Count) and not stop do
  begin
    Iterator(i,Pointer(FItems[i]),UserData,stop);
    Inc(i);
  end;
end;

Procedure TJSONlist.ForEach(Iterator:TJSONlistIteratorObj;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
Begin
  i:=0;
  stop:=False;
  while (i<FItems.Count) and not stop do
  begin
    Iterator(i,Pointer(FItems[i]),UserData,stop);
    Inc(i);
  end;
end;

function TJSONlist.GetJSON:AnsiString;
Var
  Buf:TStringStream;
Begin
  Buf:=TStringStream.Create('');
  try
    GetJSONBuf(Buf);
    Result:=Buf.DataString;
  Finally
    Buf.Free;
  end;
end;

procedure TJSONlist.GetJSONBuf(st:TStringStream);
var
  i:Integer;
  comma:Boolean;
Begin
  st.WriteString('[');
  comma:=False;
  for i:=0 to FItems.Count-1 Do
  Begin
    If comma then st.WriteString(',')
      else comma:=True;
    TJSONbase(FItems[i]).GetJSONBuf(st);
  end;
  st.WriteString(']');
end;

procedure TJSONlist.Add(B:Boolean);
var
  js:TJSONbase;
Begin
  js:=TJSONbase.Create(Self);
  js.Value:=B;
  FItems.Add(js);
end;

procedure TJSONlist.Add(I:Int64);
var
  js:TJSONbase;
Begin
  js:=TJSONbase.Create(Self);
  js.Value:=I;
  FItems.Add(js);
end;

procedure TJSONlist.Add(D:Double);
var
  js:TJSONbase;
Begin
  js:=TJSONbase.Create(Self);
  js.Value:=D;
  FItems.Add(js);
end;

procedure TJSONlist.Add(S:WideString);
var
  js:TJSONbase;
Begin
  js:=TJSONbase.Create(Self);
  js.Value:=S;
  FItems.Add(js);
end;

procedure TJSONlist.Add(A:TJSONbase);
var
  js:TJSONbase;
Begin
  If A=Nil Then
  Begin
    js:=TJSONbase.Create(Self);
    js.Value:=Null;
  end
  else js:=A;
  FItems.Add(js);
end;

Function TJSONlist.GetField(const Key:WideString):TJSONbase;
Begin
  raise TJSONError.Create(JR_LIST_NAME);
end;

procedure TJSONlist.SetField(const Key:WideString; AValue:TJSONbase);
Begin
  raise TJSONError.Create(JR_LIST_NAME);
end;

Function TJSONlist.GetName(Idx:Integer):WideString;
Begin
  raise TJSONError.Create(JR_LIST_NAME);
end;

// ===== TJSONobject =====

Constructor TJSONobject.Create(AParent:TJSONarray);
Begin
  Inherited;
  FType:=jsObject;
  FHash:=TIntegerHash.Create;
  FNames:=TStringList.Create;
end;

Destructor TJSONobject.Destroy;
Begin
  FHash.Free;
  FNames.Free;
  Inherited;
end;

Function TJSONobject.GetType:TJSONtype;
Begin
  Result:=jsObject;
end;

Function TJSONobject.GetField(const Key:WideString):TJSONbase;
var
  Idx:Integer;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Idx:=FHash.Items[Key];
  if Idx=-1 then Result:=Nil
    else Result:=Pointer(FItems[Idx]);
end;

procedure TJSONobject.SetField(const Key:WideString;AValue:TJSONbase);
var
  Idx:Integer;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Idx:=FHash.Items[Key];
  if Idx=-1 then
  Begin
    FHash.Items[Key]:=FItems.Count;
    FItems.Add(AValue);
    FNames.Add(Key);
  end
  else FItems[Idx]:=AValue;
end;

Function TJSONobject.GetName(Idx:Integer):WideString;
Begin
  if (Idx>=0)and(Idx<FNames.Count) Then Result:=FNames[Idx]
    else Raise TJSONError.CreateFmt(JR_INDEX,[Idx,FNames.Count]);
end;

Procedure TJSONobject.ForEach(Iterator:TJSONIterator;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
Begin
  i:=0;
  stop:=False;
  while (i<FItems.Count) and not stop do
  begin
    Iterator(FNames[i],Pointer(FItems[i]),UserData,stop);
    Inc(i);
  end;
end;

Procedure TJSONobject.ForEach(Iterator:TJSONIteratorObj;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
Begin
  i:=0;
  stop:=False;
  while (i<FItems.Count) and not stop do
  begin
    Iterator(FNames[i],Pointer(FItems[i]),UserData,stop);
    Inc(i);
  end;
end;

procedure TJSONobject.Delete(const Key:WideString);
var
  Idx:Integer;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Idx:=FHash.Items[Key];
  if Idx<>-1 Then
  Begin
    FHash.Delete(Key);
    FNames.Delete(Idx);
    FItems.Delete(Idx);
  end;
end;

function TJSONobject.GetJSON:AnsiString;
Var
  Buf:TStringStream;
Begin
  Buf:=TStringStream.Create('');
  try
    GetJSONBuf(Buf);
    Result:=Buf.DataString;
  Finally
    Buf.Free;
  end;
end;

procedure TJSONobject.GetJSONBuf(st:TStringStream);
var
  i:Integer;
  comma:Boolean;
Begin
  st.WriteString('{');
  comma:=False;
  for i:=0 to FItems.Count-1 Do
  Begin
    If comma then st.WriteString(',')
      else comma:=True;
    st.WriteString(EscapeString(FNames[i])+':');
    TJSONbase(FItems[i]).GetJSONBuf(st);
  end;
  st.WriteString('}');
end;

procedure TJSONobject.Add(Key:WideString;B:Boolean);
var
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  js:=TJSONbase.Create(Self);
  js.Value:=B;
  FHash.Items[Key]:=FItems.Count;
  FItems.Add(js);
  FNames.Add(Key);
end;

procedure TJSONobject.Add(Key:WideString;I:Int64);
var
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  js:=TJSONbase.Create(Self);
  js.Value:=I;
  FHash.Items[Key]:=FItems.Count;
  FItems.Add(js);
  FNames.Add(Key);
end;

procedure TJSONobject.Add(Key:WideString;D:Double);
var
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  js:=TJSONbase.Create(Self);
  js.Value:=D;
  FHash.Items[Key]:=FItems.Count;
  FItems.Add(js);
  FNames.Add(Key);
end;

procedure TJSONobject.Add(Key:WideString;S:WideString);
var
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  js:=TJSONbase.Create(Self);
  js.Value:=S;
  FHash.Items[Key]:=FItems.Count;
  FItems.Add(js);
  FNames.Add(Key);
end;

procedure TJSONobject.Add(Key:WideString;A:TJSONbase);
var
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  if A=Nil Then
  Begin
    js:=TJSONbase.Create(Self);
    js.Value:=Null;
  end
  else js:=A;
  FHash.Items[Key]:=FItems.Count;
  FItems.Add(js);
  FNames.Add(Key);
end;

// ===== Parse JSON =====

Function ParseJSON(old_pos:PAnsiChar):TJSONarray;
var
  txt:PAnsiChar;

  procedure SkipSpace;
  Begin
    while txt^ in [#9, #10, #13, ' '] do Inc(txt);
  end;

  Function ParseRoot(AParent:TJSONarray):TJSONarray; Forward;

  function ParseBase(AParent:TJSONarray):TJSONbase;
  var
    ptr:PAnsiChar;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
    is_float:Boolean;
  Begin
    Result:=Nil;
    if txt^ = #0 then Exit;
    SkipSpace;
    case txt^ of
      '"':
        Begin
          Inc(txt);
          ptr:=txt;
          escaped:=False;
          While ptr^ <> #0 Do
          Begin
            If escaped Then escaped:=False
            Else if ptr^ = '"' then Break
            else if ptr^ = '\' then escaped:=True;
            Inc(ptr);
          end;
          If ptr^ = #0 then Raise TJSONError.CreateFmt(JR_OPEN_STRING,[txt-old_pos]);
          L:=ptr-txt;
          Result:=TJSONbase.Create(AParent);
          if L>0 then
          begin
            SetLength(s,L);
            StrLCopy(@s[1],txt,L);
            Result.Value:=UnescapeString(s);
          end
          else Result.Value:='';
          txt:=ptr+1;
        end;
      'n','N':
        Begin
          If txt[1] in ['u','U'] Then
            if txt[2] in ['l','L'] Then
              if txt[3] In ['l','L'] then
              Begin
                Inc(txt,4);
                Result:=TJSONbase.Create(AParent);
                Result.Value:=Null;
              end;
        end;
      't','T':
        Begin
          if txt[1] in ['r','R'] Then
            if txt[2] in ['u','U'] Then
              if txt[3] in ['e','E'] Then
              Begin
                Inc(txt,4);
                Result:=TJSONbase.Create(AParent);
                Result.Value:=True;
              end;
        end;
      'f','F':
        Begin
          if txt[1] in ['a','A'] Then
            if txt[2] in ['l','L'] Then
              if txt[3] in ['s','S'] Then
                if txt[4] in ['e','E'] Then
                Begin
                  Inc(txt,5);
                  Result:=TJSONbase.Create(AParent);
                  Result.Value:=False;
                end;
        end;
      '-','0'..'9':
        Begin
          is_float:=False;
          ptr:=txt+1;
          while ptr^ in ['0'..'9'] do Inc(ptr); // integer part
          If ptr^ = '.' then
          Begin
            is_float:=True;
            Inc(ptr);
            if Not (ptr^ in ['0'..'9']) then Raise TJSONError.CreateFmt(JR_BAD_FLOAT,[txt-old_pos]);
            While ptr^ in ['0'..'9'] do Inc(ptr); // rational part
          end;
          if ptr^ in ['e','E'] Then
          Begin
            is_float:=True;
            Inc(ptr);
            if not (ptr^ in ['-','+','0'..'9']) then Raise TJSONError.CreateFmt(JR_BAD_EXPONENT,[txt-old_pos]);
            If ptr^ in ['+','-'] Then Inc(ptr); // exponent sign
            if not (ptr^ in ['0'..'9']) then Raise TJSONError.CreateFmt(JR_BAD_EXPONENT,[txt-old_pos]);
            While ptr^ in ['0'..'9'] do Inc(ptr); // exponent
          end;
          L:=ptr-txt;
          Result:=TJSONbase.Create(AParent);
          if L>0 Then
          begin
            SetLength(s,L);
            StrLCopy(@s[1],txt,L);
            if is_float then Result.Value:=StrToFloat(s,fmt)
              else Result.Value:=StrToInt64(s);
          End
          Else Result.Value:=0.0;
          txt:=ptr;
        end;
    Else
      Result:=ParseRoot(AParent);
    end;
  end;

  function ParseList(AParent:TJSONarray):TJSONlist; // consumes closing ]
  var
    Elem:TJSONbase;
    need_value:Boolean;
  Begin
    Result:=TJSONlist.Create(AParent);
    need_value:=False;
    While txt^ <> #0 Do
    Begin
      SkipSpace;
      if txt^ = #0 then Raise TJSONError.CreateFmt(JR_OPEN_LIST,[txt-old_pos]);
      Case txt^ Of
        ']':
          Begin
            If need_value then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            Inc(txt);
            Break;
          end;
        ',':
          begin
            if need_value or (Result.Count=0) then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            Inc(txt);
            need_value:=True;
          end;
      else
        Begin
          Elem:=ParseBase(Result);
          If not Assigned(Elem) then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
          Result.Add(Elem);
          need_value:=False;
        end;
      end;
    end;
  end;

  Function ParseName:WideString;
  var
    ptr:PAnsiChar;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
  Begin
    SkipSpace;
    if txt^ = '"' Then
    begin
      Inc(txt);
      ptr:=txt;
      escaped:=False;
      While ptr^ <> #0 Do
      Begin
        If escaped Then escaped:=False
        Else if ptr^ = '"' then Break
        else if ptr^ = '\' then escaped:=True;
        Inc(ptr);
      end;
      If ptr^ = #0 then Raise TJSONError.CreateFmt(JR_OPEN_STRING,[txt-old_pos]);
      L:=ptr-txt;
      if L>0 Then
      begin
        SetLength(s,L);
        StrLCopy(@s[1],txt,L);
        Result:=UnescapeString(s);
      End
      else raise TJSONError.CreateFmt(JR_EMPTY_NAME,[txt-old_pos]);
      txt:=ptr+1;
    End
    Else raise TJSONError.CreateFmt(JR_UNQUOTED,[txt-old_pos]);
  end;

  function ParseObject(AParent:TJSONarray):TJSONobject; // consumes closing }
  var
    Title:WideString;
    Elem:TJSONbase;
    need_value:Boolean;
  Begin
    Result:=TJSONobject.Create(AParent);
    need_value:=False;
    While txt^ <> #0 Do
    Begin
      SkipSpace;
      if txt^ = #0 then Raise TJSONError.CreateFmt(JR_OPEN_LIST,[txt-old_pos]);
      Case txt^ Of
        '}':
          Begin
            If need_value then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            Inc(txt);
            Break;
          end;
        ',':
          begin
            if need_value or (Result.Count=0) then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            Inc(txt);
            need_value:=True;
          end;
      else
        Begin
          Title:=ParseName;
          SkipSpace;
          If txt^ <> ':' then Raise TJSONError.CreateFmt(JR_NO_COLON,[txt-old_pos]);
          Inc(txt);
          SkipSpace;
          if txt^ in [',','}'] then raise TJSONError.CreateFmt(JR_NO_VALUE,[txt-old_pos]);
          Elem:=ParseBase(Result);
          If not Assigned(Elem) then Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
          Result.Add(Title,Elem);
          need_value:=False;
        end;
      end;
    end;
  end;

  Function ParseRoot(AParent:TJSONarray):TJSONarray;
  begin
    Result:=Nil;
    While txt^ <> #0 do
    Begin
      SkipSpace;
      if txt^ = #0 Then Break;
      case txt^ Of
        '{':
          begin
            Inc(txt);
            Result:=ParseObject(AParent);
            Break;
          End;
        '[':
          Begin
            Inc(txt);
            Result:=ParseList(AParent);
            Break;
          end;
      Else
        Raise TJSONError.CreateFmt(JR_PARSE_CHAR,[txt-old_pos]);
      end;
    end;
  end;

Begin
  txt:=old_pos;
  Result:=Nil;
  if txt<>NIL then 
  try
    Result:=ParseRoot(Nil);
    SkipSpace;
    If txt^ <> #0 Then Raise TJSONError.CreateFmt(JR_PARSE_CHAR,[txt-old_pos]);
  Except
    if Assigned(Result) then FreeAndNil(Result);
    Raise;
  End;
end;

Initialization
  GetLocaleFormatSettings(GetSystemDefaultLCID,fmt);
  fmt.DecimalSeparator:='.';
  fmt.ThousandSeparator:=#0;

end.
