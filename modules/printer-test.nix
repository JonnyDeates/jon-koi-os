{ config, pkgs, lib, username, ... }:

let
  printerTestScript = pkgs.writeShellScript "printer-test" ''
    LOG_TAG="printer-test"
    echo "[$LOG_TAG] $(date '+%Y-%m-%d %H:%M:%S') Sending test page to Epson ET-2850"

    # Generate a PostScript test page with color blocks (exercises C, M, Y, K heads)
    TEST_FILE=$(mktemp /tmp/printer-test-XXXXXX.ps)
    cat > "$TEST_FILE" << 'PSEOF'
%!PS-Adobe-3.0
%%Title: Printer Head Maintenance Test Page
%%Pages: 1
%%PageOrder: Ascend
%%EndComments

%%Page: 1 1

% Title
/Helvetica-Bold findfont 24 scalefont setfont
72 720 moveto
(Epson ET-2850 - Head Maintenance Print) show

/Helvetica findfont 14 scalefont setfont
72 690 moveto
(%DATE%) show

% Black block
0 0 0 setrgbcolor
72 600 144 50 rectfill
1 1 1 setrgbcolor
/Helvetica findfont 12 scalefont setfont
80 620 moveto (Black) show

% Cyan block
0 1 1 setrgbcolor
72 530 144 50 rectfill
0 0 0 setrgbcolor
80 550 moveto (Cyan) show

% Magenta block
1 0 1 setrgbcolor
72 460 144 50 rectfill
1 1 1 setrgbcolor
80 480 moveto (Magenta) show

% Yellow block
1 1 0 setrgbcolor
72 390 144 50 rectfill
0 0 0 setrgbcolor
80 410 moveto (Yellow) show

% Gradient bar (exercises all channels at varying intensities)
0 1 100 {
  /i exch def
  i 100 div 0 0 setrgbcolor
  72 i 3.2 mul 310 add moveto
  108 0 rlineto 0 3 rlineto -108 0 rlineto closepath fill
} for

0 1 100 {
  /i exch def
  0 i 100 div 0 setrgbcolor
  190 i 3.2 mul 310 add moveto
  108 0 rlineto 0 3 rlineto -108 0 rlineto closepath fill
} for

0 1 100 {
  /i exch def
  0 0 i 100 div setrgbcolor
  308 i 3.2 mul 310 add moveto
  108 0 rlineto 0 3 rlineto -108 0 rlineto closepath fill
} for

showpage
%%EOF
PSEOF

    # Stamp the date into the PostScript
    ${pkgs.gnused}/bin/sed -i "s/%DATE%/$(date '+%Y-%m-%d %H:%M')/" "$TEST_FILE"

    # Send to printer
    ${pkgs.cups}/bin/lp -d EPSON_ET_2850_Series "$TEST_FILE"
    RESULT=$?

    rm -f "$TEST_FILE"

    if [ "$RESULT" -eq 0 ]; then
      echo "[$LOG_TAG] Test page sent successfully."
    else
      echo "[$LOG_TAG] ERROR: Failed to send test page (exit $RESULT)."
      exit 1
    fi
  '';
in
{
  config = {
    systemd.services.printer-test = {
      description = "Send color test page to Epson ET-2850 to prevent head clogs";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = "${username}";
        ExecStart = "${printerTestScript}";
      };
    };

    systemd.timers.printer-test = {
      description = "Bi-weekly Epson printer test print";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-01,15 10:00:00";
        Persistent = true;
        Unit = "printer-test.service";
      };
    };
  };
}
