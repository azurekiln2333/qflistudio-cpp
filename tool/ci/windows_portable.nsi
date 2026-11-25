; NSIS 3 script for the Windows single-file edition.
; tool/ci/package_app.py passes every definition below.
;
; The file is a launcher, not an installer. It copies the application to
; %LOCALAPPDATA%\QFLIForge\portable\<build id>, writes a marker file after the
; last file, and starts the application with the caller's arguments. A later
; start finds the marker and starts the application at once.
;
; /EXTRACTONLY [directory] copies the files and starts nothing. The workflow
; compares that copy with the build output.

Unicode True
ManifestDPIAware true
RequestExecutionLevel user

!include "FileFunc.nsh"
!include "LogicLib.nsh"

!ifndef BuildId
  !error "BuildId is required"
!endif
!ifndef ApplicationDir
  !error "ApplicationDir is required"
!endif
!ifndef OutputFile
  !error "OutputFile is required"
!endif
!ifndef IconFile
  !error "IconFile is required"
!endif
!ifndef FileVersion
  !error "FileVersion is required"
!endif

!define AppName "QFLIForge"
!define AppExe "qfli_c.exe"
; Keep this value equal to package_app.PORTABLE_MARKER.
!define MarkerName ".qfli-portable-complete"

Name "${AppName}"
OutFile "${OutputFile}"
Icon "${IconFile}"
ShowInstDetails nevershow
AutoCloseWindow true
SilentInstall silent
XPStyle on
VIProductVersion "${FileVersion}"
VIAddVersionKey /LANG=1033 "ProductName" "${AppName}"
VIAddVersionKey /LANG=1033 "FileDescription" "${AppName} single-file edition"
VIAddVersionKey /LANG=1033 "FileVersion" "${FileVersion}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "GNU General Public License version 3"

Var Target
Var Arguments

!macro ExtractApplication
  SetOutPath "$Target"
  File /r "${ApplicationDir}\*.*"
  FileOpen $0 "$Target\${MarkerName}" w
  FileWrite $0 "${BuildId}$\r$\n"
  FileClose $0
!macroend

Function .onInit
  ${GetParameters} $R0
  ${GetOptions} $R0 "/EXTRACTONLY" $Target
  ${IfNot} ${Errors}
    ; GetOptions trims the separator and removes surrounding quotes itself.
    ${If} $Target == ""
      StrCpy $Target "$EXEDIR\${AppName}"
    ${EndIf}
    CreateDirectory "$Target"
    ClearErrors
    Delete "$Target\${MarkerName}"
    !insertmacro ExtractApplication
    SetErrorLevel 0
    Quit
  ${EndIf}

  ; The switch is absent here, so every parameter belongs to the application.
  StrCpy $Arguments "$R0"
  StrCpy $Target "$LOCALAPPDATA\${AppName}\portable\${BuildId}"
  ${If} ${FileExists} "$Target\${MarkerName}"
    Call StartApplication
  ${EndIf}

  ; The first start, or an interrupted earlier extraction: copy every file again.
  CreateDirectory "$Target"
  ClearErrors
  Delete "$Target\${MarkerName}"
  !insertmacro ExtractApplication
  Call StartApplication
FunctionEnd

Function StartApplication
  ; The working directory is the application directory, so that the DLL search
  ; finds the Flutter libraries. The arguments reach the application unchanged.
  SetOutPath "$Target"
  ${If} $Arguments == ""
    Exec '"$Target\${AppExe}"'
  ${Else}
    Exec '"$Target\${AppExe}" $Arguments'
  ${EndIf}
  SetErrorLevel 0
  Quit
FunctionEnd

Section
  ; .onInit quits before this section on every path.
SectionEnd
