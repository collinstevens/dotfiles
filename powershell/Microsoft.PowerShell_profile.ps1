# Silence PSReadLine's beep (e.g. backspace at the start of the prompt).
# This plays via Console.Beep, so Windows Terminal's bellStyle can't suppress it.
Set-PSReadLineOption -BellStyle None
