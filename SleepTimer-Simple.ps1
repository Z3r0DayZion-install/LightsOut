# Sleep Timer Pro - Simple Version
param(
    [int]$Minutes = 30,
    [string]$Action = "Sleep"
)

Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sleep Timer Pro"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Sleep Timer - $Minutes minutes`nAction: $Action"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$label.Size = New-Object System.Drawing.Size(350, 60)
$label.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($label)

$startBtn = New-Object System.Windows.Forms.Button
$startBtn.Text = "START TIMER"
$startBtn.Size = New-Object System.Drawing.Size(150, 40)
$startBtn.Location = New-Object System.Drawing.Point(120, 100)
$startBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$startBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$startBtn.ForeColor = [System.Drawing.Color]::White
$startBtn.Add_Click({
    $startBtn.Enabled = $false
    $startBtn.Text = "RUNNING..."
    
    $seconds = $Minutes * 60
    for ($i = $seconds; $i -gt 0; $i--) {
        $min = [math]::Floor($i / 60)
        $sec = $i % 60
        $label.Text = "Time remaining: {0:D2}:{1:D2}`nAction: $Action" -f $min, $sec
        $form.Refresh()
        Start-Sleep -Seconds 1
    }
    
    $label.Text = "Executing $Action..."
    $form.Refresh()
    Start-Sleep -Seconds 2
    
    switch ($Action) {
        "Sleep" { rundll32.exe powrprof.dll,SetSuspendState 0,1,0 }
        "Shutdown" { Stop-Computer -Force }
        "Restart" { Restart-Computer -Force }
        "Hibernate" { rundll32.exe powrprof.dll,SetSuspendState 1,1,0 }
    }
    $form.Close()
})
$form.Controls.Add($startBtn)

$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Text = "Cancel"
$cancelBtn.Size = New-Object System.Drawing.Size(100, 30)
$cancelBtn.Location = New-Object System.Drawing.Point(145, 160)
$cancelBtn.Add_Click({ $form.Close() })
$form.Controls.Add($cancelBtn)

$form.ShowDialog()
