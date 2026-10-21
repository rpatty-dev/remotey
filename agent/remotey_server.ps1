# Remotey Server for Windows 🖥️
# Zero-dependency, native PowerShell TCP server for autonomous agent computer-use.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$Win32 = @"
using System;
using System.Runtime.InteropServices;
public class Win32Input {
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, int e);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int m);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;
}
"@
Add-Type -TypeDefinition $Win32

$port = if ($env:REMOTEY_PORT) { [int]$env:REMOTEY_PORT } else { 7777 }

# Ensure Windows Firewall rule exists
try {
    if (-not (Get-NetFirewallRule -DisplayName "Remotey" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "Remotey" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
    }
} catch {}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Remotey Computer-Use Server Starting..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Bind to 0.0.0.0 (all network interfaces, including Tailscale, LAN, and Loopback)
try {
    $ipAny = [System.Net.IPAddress]::Any
    $tcp = New-Object System.Net.Sockets.TcpListener -ArgumentList $ipAny, $port
    $tcp.Start()
    Write-Host "[SUCCESS] Listening on 0.0.0.0:$($port) (ALL INTERFACES)" -ForegroundColor Green
    Write-Host "[SUCCESS] Ready for Antigravity / Claude / Cursor / OpenDevin agent connections!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not bind port: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "`nWaiting for autonomous commands..." -ForegroundColor White

while ($true) {
    $client = $null
    try {
        $client = $tcp.AcceptTcpClient()
        $remoteEndpoint = $client.Client.RemoteEndPoint.ToString()
        Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] CONNECTED: $remoteEndpoint" -ForegroundColor Green

        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader -ArgumentList $stream
        $writer = New-Object System.IO.StreamWriter -ArgumentList $stream
        $writer.AutoFlush = $true

        $line = $reader.ReadLine()
        if (-not $line) { if ($client) { $client.Close() }; continue }

        $parts = $line.Split(' ')
        $method = $parts[0]
        $path = $parts[1]
        Write-Host "  -> $method $path" -ForegroundColor DarkGray

        # Read HTTP headers
        $contentLength = 0
        while ($h = $reader.ReadLine()) {
            if ($h -eq '') { break }
            if ($h -match '^Content-Length:\s*(\d+)') { $contentLength = [int]$matches[1] }
        }

        # Read HTTP request body
        $body = ''
        if ($contentLength -gt 0) {
            $buffer = New-Object "char[]" $contentLength
            $readTotal = 0
            while ($readTotal -lt $contentLength) {
                $n = $reader.Read($buffer, $readTotal, $contentLength - $readTotal)
                if ($n -le 0) { break }
                $readTotal += $n
            }
            $body = New-Object -TypeName System.String -ArgumentList $buffer, 0, $readTotal
        }

        if ($path -eq '/status' -or $path -eq '/info') {
            $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $c = [System.Windows.Forms.Cursor]::Position
            $h = [Win32Input]::GetForegroundWindow()
            $s = New-Object System.Text.StringBuilder -ArgumentList 256
            [Win32Input]::GetWindowText($h, $s, 256) | Out-Null
            $json = @{ 
                ok = $true; 
                width = $b.Width; 
                height = $b.Height; 
                cursorX = $c.X; 
                cursorY = $c.Y; 
                activeWindow = $s.ToString(); 
                host = $env:COMPUTERNAME;
                user = $env:USERNAME 
            } | ConvertTo-Json

            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($json.Length)")
            $writer.WriteLine('')
            $writer.Write($json)
        }
        elseif ($path -eq '/screenshot') {
            $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $bmp = New-Object System.Drawing.Bitmap -ArgumentList $b.Width, $b.Height
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
            $g.Dispose()

            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            $data = $ms.ToArray()
            $ms.Dispose()

            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: image/png')
            $writer.WriteLine("Content-Length: $($data.Length)")
            $writer.WriteLine('')
            $writer.Flush()
            $stream.Write($data, 0, $data.Length)
        }
        elseif ($path -eq '/click') {
            $obj = $body | ConvertFrom-Json
            [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point -ArgumentList ([int]$obj.x), ([int]$obj.y)
            Start-Sleep -Milliseconds 25
            if ($obj.button -eq 'right') {
                [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
                Start-Sleep -Milliseconds 20
                [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
            } else {
                [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                Start-Sleep -Milliseconds 20
                [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
            }
            $resJson = '{"ok":true}'
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        elseif ($path -eq '/move') {
            $obj = $body | ConvertFrom-Json
            [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point -ArgumentList ([int]$obj.x), ([int]$obj.y)
            $resJson = '{"ok":true}'
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        elseif ($path -eq '/type') {
            $obj = $body | ConvertFrom-Json
            $esc = $obj.text -replace '([+^%~(){}[\]])', '{$1}'
            [System.Windows.Forms.SendKeys]::SendWait($esc)
            $resJson = '{"ok":true}'
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        elseif ($path -eq '/key' -or $path -eq '/hotkey') {
            $obj = $body | ConvertFrom-Json
            $k = if ($obj.key) { $obj.key } else { $obj.keys }
            $map = @{ 'enter'='{ENTER}'; 'tab'='{TAB}'; 'esc'='{ESC}'; 'backspace'='{BACKSPACE}' }
            $v = if ($map.ContainsKey($k.ToLower())) { $map[$k.ToLower()] } else { $k }
            [System.Windows.Forms.SendKeys]::SendWait($v)
            $resJson = '{"ok":true}'
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        elseif ($path -eq '/scroll') {
            $obj = $body | ConvertFrom-Json
            $amt = if ($obj.amount) { [int]$obj.amount } else { -200 }
            [Win32Input]::mouse_event([Win32Input]::MOUSEEVENTF_WHEEL, 0, 0, [uint32]$amt, 0)
            $resJson = '{"ok":true}'
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        elseif ($path -eq '/run') {
            $obj = $body | ConvertFrom-Json
            $out = powershell.exe -NoProfile -Command $obj.command 2>&1 | Out-String
            $resJson = @{ ok = $true; stdout = $out } | ConvertTo-Json
            $writer.WriteLine('HTTP/1.1 200 OK')
            $writer.WriteLine('Access-Control-Allow-Origin: *')
            $writer.WriteLine('Content-Type: application/json')
            $writer.WriteLine("Content-Length: $($resJson.Length)")
            $writer.WriteLine('')
            $writer.Write($resJson)
        }
        else {
            $writer.WriteLine('HTTP/1.1 404 Not Found')
            $writer.WriteLine('Content-Length: 0')
            $writer.WriteLine('')
        }
    } catch {
        try {
            $err = $_.Exception.Message
            $writer.WriteLine('HTTP/1.1 500 Error')
            $writer.WriteLine('Content-Type: text/plain')
            $writer.WriteLine("Content-Length: $($err.Length)")
            $writer.WriteLine('')
            $writer.Write($err)
        } catch {}
    } finally {
        if ($client) { $client.Close() }
    }
}
