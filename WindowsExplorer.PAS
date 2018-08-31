UNIT WindowsExplorer;

INTERFACE

USES Types,ShDocVw;

FUNCTION ExploreDirectory(CONST Dir : STRING) : BOOLEAN;
FUNCTION OpenFolder(CONST Dir : STRING) : IWebBrowserApp; OVERLOAD;
FUNCTION OpenFolderAt(CONST Dir : STRING ; Left,Top,Width,Height : INTEGER) : IWebBrowserApp; OVERLOAD;
FUNCTION OpenFolderAt(CONST Dir : STRING ; CONST Rect : TRect) : IWebBrowserApp; OVERLOAD; INLINE;

IMPLEMENTATION

USES Windows,Variants,ShlObj,Ole2,OleAuto,ShellAPI,ActiveX,SysUtils;

FUNCTION ExploreDirectory(CONST Dir : STRING) : BOOLEAN;
  BEGIN
    Result:=(ShellExecute(GetDesktopWindow,'open',PChar(Dir),'','',SW_SHOW)>32)
  END;

FUNCTION GetFolderIDList(CONST Dir : STRING) : PItemIDList;
  VAR
    ShellFolder	: IShellFolder;
    Attributes	: ULONG;
    Count	: ULONG;

  BEGIN
    OleCheck(SHGetDesktopFolder(ShellFolder));
    Attributes:=SFGAO_FOLDER or SFGAO_STREAM;
    OleCheck(ShellFolder.ParseDisplayName(0,NIL,PWideChar(WideString(Dir)),Count,Result,Attributes));
    IF NOT ((Attributes AND SFGAO_FOLDER=SFGAO_FOLDER) AND (Attributes AND SFGAO_STREAM<>SFGAO_STREAM)) THEN BEGIN
      CoTaskMemFree(Result);
      Result:=NIL
    END
  END;

FUNCTION OpenFolder(CONST Dir : STRING ; OpenIfNotFound : BOOLEAN) : IWebBrowserApp; OVERLOAD;
  CONST
    IID_IServiceProvider: System.TGUID = '{6D5140C1-7436-11CE-8034-00AA006009FA}';

  VAR
    FolderID		: PItemIDList;
    ShellWindows	: IShellWindows;
    I			: INTEGER;
    WndIFace		: System.IDispatch;
    WebBrowserApp	: IWebBrowserApp;
    ServiceProvider	: IServiceProvider;
    ShellBrowser	: IShellBrowser;
    ShellView		: IShellView;
    FolderView		: IFolderView;
    PersistFolder	: IPersistFolder2;
    CurFolderID		: PItemIDList;

  BEGIN
    FolderID:=GetFolderIDList(Dir);
    TRY
      OleCheck(CoCreateInstance(CLASS_ShellWindows,NIL,CLSCTX_LOCAL_SERVER,IID_IShellWindows,ShellWindows));
      FOR I:=0 TO PRED(ShellWindows.Count) DO BEGIN
        WndIface:=ShellWindows.Item(VarAsType(I,VT_I4));
        IF Assigned(WndIface) AND
           Succeeded(WndIface.QueryInterface(IID_IWebBrowserApp,WebBrowserApp)) AND
           Succeeded(WebBrowserApp.QueryInterface(IID_IServiceProvider,ServiceProvider)) AND
           Succeeded(ServiceProvider.QueryService(SID_STopLevelBrowser,IID_IShellBrowser,ShellBrowser)) AND
           Succeeded(ShellBrowser.QueryActiveShellView(ShellView)) AND
           Succeeded(ShellView.QueryInterface(IID_IFolderView,FolderView)) AND
           Succeeded(FolderView.GetFolder(IID_IPersistFolder2,PersistFolder)) AND
           Succeeded(PersistFolder.GetCurFolder(CurFolderID)) AND
           ILIsEqual(FolderID,CurFolderID) THEN BEGIN
          IF IsIconic(WebBrowserApp.HWnd) THEN Win32Check(ShowWindow(WebBrowserApp.HWnd,SW_RESTORE));
          Win32Check(SetForegroundWindow(WebBrowserApp.HWnd));
          Exit(WebBrowserApp)
        END
      END
    FINALLY
      CoTaskMemFree(FolderID)
    END;
    Result:=NIL;
    IF OpenIfNotFound THEN BEGIN
      IF NOT ExploreDirectory(Dir) THEN EXIT;
      FOR I:=1 TO 20 DO BEGIN
        Result:=OpenFolder(Dir,FALSE);
        IF Assigned(Result) THEN EXIT;
        Sleep(100)
      END
    END
  END;

FUNCTION OpenFolder(CONST Dir : STRING) : IWebBrowserApp;
  BEGIN
    Result:=OpenFolder(Dir,TRUE)
  END;

FUNCTION OpenFolderAt(CONST Dir : STRING ; Left,Top,Width,Height : INTEGER) : IWebBrowserApp;
  BEGIN
    Result:=OpenFolder(Dir);
    IF Assigned(Result) THEN BEGIN
      Result.Left:=Left; Result.Top:=Top; Result.Width:=Width; Result.Height:=Height
    END
  END;

FUNCTION OpenFolderAt(CONST Dir : STRING ; CONST Rect : TRect) : IWebBrowserApp;
  BEGIN
    Result:=OpenFolderAt(Dir,Rect.Left,Rect.Top,Rect.Width,Rect.Height)
  END;

END.
