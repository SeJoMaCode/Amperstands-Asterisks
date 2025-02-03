function Write-ColoredText {
    param (
        [Parameter(Mandatory)]
        [array]$TextParts,  # Array of text parts with color and background
        [int]$X = 0,        # X-coordinate (column)
        [int]$Y = 0         # Y-coordinate (row)
    )

    # Set the cursor position
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates($X, $Y)

    # Write each part of the text with its specified foreground and background color
    foreach ($part in $TextParts) {
        Write-Host $part.Text -ForegroundColor $part.Color -BackgroundColor $part.BackgroundColor -NoNewline
    }
    Write-Host ""  # Move to the next line after printing
}

class ConsoleBox {
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [string]$BorderColor
    [string]$BackgroundColor

    ConsoleBox([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.BorderColor = "White"
        $this.BackgroundColor = "Black"
    }

    # Method to draw the box with ASCII characters
    [void] DrawBox() {
        # Draw top border
        $topBorder = @{
            Text = "+" + "-" * ($this.Width - 2) + "+"
            Color = $this.BorderColor
            BackgroundColor = $this.BackgroundColor
        }
        Write-ColoredText -TextParts @($topBorder) -X $this.X -Y $this.Y

        # Draw sides
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            $sides = @(
                @{
                    Text = "|"
                    Color = $this.BorderColor
                    BackgroundColor = $this.BackgroundColor
                },
                @{
                    Text = " " * ($this.Width - 2)
                    Color = $this.BorderColor
                    BackgroundColor = $this.BackgroundColor
                },
                @{
                    Text = "|"
                    Color = $this.BorderColor
                    BackgroundColor = $this.BackgroundColor
                }
            )
            Write-ColoredText -TextParts $sides -X $this.X -Y ($this.Y + $i)
        }

        # Draw bottom border
        $bottomBorder = @{
            Text = "+" + "-" * ($this.Width - 2) + "+"
            Color = $this.BorderColor
            BackgroundColor = $this.BackgroundColor
        }
        Write-ColoredText -TextParts @($bottomBorder) -X $this.X -Y ($this.Y + $this.Height - 1)
    }

    # Method to write colored content inside the box
    [void] WriteContent([array]$textParts, [int]$lineNumber, [int]$xOffset=0) {
        if ($lineNumber -ge ($this.Height - 2)) {
            return
        }
        
        # Calculate total length of text
        $totalLength = ($textParts | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum
        if ($totalLength -gt ($this.Width - 4)) {
            return  # Text too long for box
        }

        # Adjust X position to account for box border
        $adjustedX = $this.X + 2 + $xOffset
        Write-ColoredText -TextParts $textParts -X $adjustedX -Y ($this.Y + $lineNumber + 1)
    }
	
	# Method to write colored content inside the box
    [void] WriteContent([array]$textParts, [int]$lineNumber) {
        if ($lineNumber -ge ($this.Height - 2)) {
            return
        }
        
        # Calculate total length of text
        $totalLength = ($textParts | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum
        if ($totalLength -gt ($this.Width - 4)) {
            return  # Text too long for box
        }

        # Adjust X position to account for box border
        $adjustedX = $this.X + 2
        Write-ColoredText -TextParts $textParts -X $adjustedX -Y ($this.Y + $lineNumber + 1)
    }
	
    # Method to clear a specific line
    [void] ClearLine([int]$lineNumber) {
        if ($lineNumber -ge ($this.Height - 2)) {
            return
        }

        $clearLine = @{
            Text = " " * ($this.Width - 2)
            Color = $this.BorderColor
            BackgroundColor = $this.BackgroundColor
        }
        Write-ColoredText -TextParts @($clearLine) -X ($this.X + 1) -Y ($this.Y + $lineNumber + 1)
    }

    # Method to clear a specific region
    [void] ClearRegion([int]$startLine, [int]$endLine) {
        $startLine = [Math]::Max(0, $startLine)
        $endLine = [Math]::Min($this.Height - 2, $endLine)

        for ($i = $startLine; $i -le $endLine; $i++) {
            $this.ClearLine($i)
        }
    }
	
	[void] ClearContent() {
        $this.ClearRegion(0, $this.Height - 2)
    }
	
	# Get inner width (usable space inside the box)
    [int] GetInnerWidth() {
        return $this.Width - 4  # Subtract 4 for the borders
    }

    # Get inner height (usable space inside the box)
    [int] GetInnerHeight() {
        return $this.Height - 2  # Subtract 3 for the borders
    }

    # Get inner left position (first usable column)
    [int] GetInnerLeft() {
        return 0
    }

    # Get inner top position (first usable row)
    [int] GetInnerTop() {
        return 1
    }

}

class MapManager {
    [array]$Grid
    [hashtable]$Colors
    [hashtable]$Walkable
    [int]$PlayerX
    [int]$PlayerY
    [int]$LastPlayerX
    [int]$LastPlayerY
    [ConsoleBox]$GameBox

    MapManager([ConsoleBox]$gameBox) {
        $this.GameBox = $gameBox
        
        # Initialize map properties
        $this.Colors = @{
            '.' = "DarkGray"   # floor
            '#' = "White"      # wall
            '@' = "Green"      # player
        }
        
        $this.Walkable = @{
            '.' = $true
            '#' = $false
            '@' = $false
        }

        # Convert dungeon format to our grid format
        $dungeon = New-Dungeon -width ($gameBox.GetInnerWidth()) -height ($gameBox.GetInnerHeight())
        
		# Create the grid array
        $this.Grid = @()
        
        # Convert each row of the dungeon to our format
        foreach ($row in $dungeon) {
            $newRow = @()
            foreach ($cell in $row) {
                $newRow += if ($cell -eq 1) { '#' } else { '.' }
            }
            $this.Grid += ,$newRow
        }

        # Find a valid starting position for the player
        $startPos = $this.FindValidStartPosition()
        $this.PlayerX = $startPos.X
        $this.PlayerY = $startPos.Y
        $this.LastPlayerX = $this.PlayerX
        $this.LastPlayerY = $this.PlayerY
        
        $this.DrawFullMap()
    }

    # Method to find a valid starting position
    [hashtable] FindValidStartPosition() {
        for ($y = 0; $y -lt $this.Grid.Count; $y++) {
            for ($x = 0; $x -lt $this.Grid[$y].Count; $x++) {
                if ($this.Grid[$y][$x] -eq '.') {
                    return @{
                        X = $x
                        Y = $y
                    }
                }
            }
        }
        # Fallback to position 1,1 if no valid position found
        return @{
            X = 1
            Y = 1
        }
    }

    # Rest of the MapManager methods remain the same
    [void] DrawFullMap() {
        for ($y = 0; $y -lt $this.Grid.Count; $y++) {
            $rowParts = @()
            $row = $this.Grid[$y]
            
            for ($x = 0; $x -lt $row.Count; $x++) {
                $char = $row[$x]
                if ($x -eq $this.PlayerX -and $y -eq $this.PlayerY) {
                    $char = '@'
                }
                
                $rowParts += @{
                    Text = $char
                    Color = $this.Colors[$char]
                    BackgroundColor = "Black"
                }
            }
            
            $this.GameBox.WriteContent($rowParts, $y)
        }
    }

    [bool] IsValidMove([int]$newX, [int]$newY) {
        if ($newX -lt 0 -or $newX -ge $this.Grid[0].Count -or 
            $newY -lt 0 -or $newY -ge $this.Grid.Count) {
            return $false
        }
        return $this.Walkable[$this.Grid[$newY][$newX]]
    }

    [void] MovePlayer([int]$deltaX, [int]$deltaY) {
        $newX = $this.PlayerX + $deltaX
        $newY = $this.PlayerY + $deltaY

        if ($this.IsValidMove($newX, $newY)) {
            # Draw floor tile at old position
            $oldChar = $this.Grid[$this.PlayerY][$this.PlayerX]
            $this.GameBox.WriteContent(@(@{
                Text = $oldChar
                Color = $this.Colors[$oldChar]
                BackgroundColor = "Black"
            }), $this.PlayerY, $this.PlayerX)

            # Update player position
            $this.PlayerX = $newX
            $this.PlayerY = $newY

            # Draw player at new position
            $this.GameBox.WriteContent(@(@{
                Text = '@'
                Color = $this.Colors['@']
                BackgroundColor = "Black"
            }), $this.PlayerY, $this.PlayerX)
        }
    }
}

class StatsManager {
    [ConsoleBox]$StatsBox
    [hashtable]$Stats
    [hashtable]$Colors
    [hashtable]$Formatters

    StatsManager([ConsoleBox]$statsBox) {
        $this.StatsBox = $statsBox
        
        # Initialize default stats
        $this.Stats = @{
            HP = @{ Current = 100; Max = 100 }
            MP = @{ Current = 50; Max = 50 }
            Level = 5
            Experience = @{ Current = 450; Max = 1000 }
            Gold = 1250
            Strength = 15
            Defense = 12
            Speed = 10
        }

        # Define colors for different stats
        $this.Colors = @{
            HP = "Green"
            MP = "Blue"
            Level = "Magenta"
            Experience = "White"
            Gold = "Yellow"
            Strength = "Red"
            Defense = "Cyan"
            Speed = "Gray"
        }

        # Define custom formatters for stats
        $this.Formatters = @{
            HP = { param($stat) "HP: $($stat.Current)/$($stat.Max)" }
            MP = { param($stat) "MP: $($stat.Current)/$($stat.Max)" }
            Level = { param($stat) "Level: $stat" }
            Experience = { param($stat) "EXP: $($stat.Current)/$($stat.Max)" }
            Gold = { param($stat) "Gold: $stat" }
            Strength = { param($stat) "STR: $stat" }
            Defense = { param($stat) "DEF: $stat" }
            Speed = { param($stat) "SPD: $stat" }
        }

        # Initial render
        $this.RenderStats()
    }

    # Method to update a specific stat
    [void] UpdateStat([string]$statName, $value) {
        $this.Stats[$statName] = $value
        $this.RenderStats()
    }

    # Method to update HP or MP
    [void] UpdateResourceStat([string]$statName, [int]$current, [int]$max) {
        $this.Stats[$statName] = @{
            Current = [Math]::Min($current, $max)
            Max = $max
        }
        $this.RenderStats()
    }

    # Method to add experience points
    [void] AddExperience([int]$amount) {
        $this.Stats.Experience.Current += $amount
        
        while ($this.Stats.Experience.Current -ge $this.Stats.Experience.Max) {
            $this.Stats.Experience.Current -= $this.Stats.Experience.Max
            $this.LevelUp()
        }
        
        $this.RenderStats()
    }

    # Method to handle leveling up
    [void] LevelUp() {
        $this.Stats.Level++
        $this.Stats.Experience.Max = [Math]::Floor($this.Stats.Experience.Max * 1.5)
        
        # Increase max HP and MP on level up
        $this.Stats.HP.Max += 10
        $this.Stats.HP.Current = $this.Stats.HP.Max
        $this.Stats.MP.Max += 5
        $this.Stats.MP.Current = $this.Stats.MP.Max
        
        # Increase other stats
        $this.Stats.Strength += 2
        $this.Stats.Defense += 2
        $this.Stats.Speed += 1
    }

    # Method to add or remove gold
    [void] ModifyGold([int]$amount) {
        $this.Stats.Gold += $amount
        if ($this.Stats.Gold -lt 0) {
            $this.Stats.Gold = 0
        }
        $this.RenderStats()
    }

    # Method to render all stats
    [void] RenderStats() {
        # Clear the stats box first
        # $this.StatsBox.ClearContent()

        # Draw the header
        $this.StatsBox.WriteContent(@(
            @{
                Text = "Character Stats"
                Color = "Yellow"
                BackgroundColor = "Black"
            }
        ), 0)

        # Define the order of stats
        $statOrder = @(
            "HP",
            "MP",
            "Level",
            "Experience",
            "",  # Empty line
            "Gold",
            "",  # Empty line
            "Strength",
            "Defense",
            "Speed"
        )

        # Render each stat in order
        $line = 2  # Start after header
        foreach ($statName in $statOrder) {
            if ($statName -eq "") {
                $line++  # Add empty line
                continue
            }

            if ($this.Stats.ContainsKey($statName)) {
                $formatter = $this.Formatters[$statName]
                $formattedText = $formatter.Invoke($this.Stats[$statName])

                $this.StatsBox.WriteContent(@(
                    @{
                        Text = $formattedText
                        Color = $this.Colors[$statName]
                        BackgroundColor = "Black"
                    }
                ), $line)
            }
            $line++
        }
    }

    # Method to get current value of a stat
    [object] GetStat([string]$statName) {
        return $this.Stats[$statName]
    }

    # Method to check if character has enough resources (HP, MP, Gold)
    [bool] HasEnoughResource([string]$resourceName, [int]$amount) {
        $result = switch ($resourceName) {
            "Gold" { $this.Stats.Gold -ge $amount }
            "HP" { $this.Stats.HP.Current -ge $amount }
            "MP" { $this.Stats.MP.Current -ge $amount }
            default { $false }
        }
        return $result
    }
}

class FrameTimer {
    [DateTime]$LastFrame
    [int]$TargetFPS
    [int]$FrameTimeMs
    [double]$CurrentFPS
    [int]$FrameCount
    [DateTime]$LastFPSUpdate

    FrameTimer([int]$targetFPS = 30) {
        $this.TargetFPS = $targetFPS
        $this.FrameTimeMs = [Math]::Floor(1000 / $targetFPS)
        $this.LastFrame = Get-Date
        $this.LastFPSUpdate = Get-Date
        $this.FrameCount = 0
    }

    [void] WaitForNextFrame() {
        $this.FrameCount++
        $now = Get-Date
        $elapsed = ($now - $this.LastFrame).TotalMilliseconds
        
        if ($elapsed -lt $this.FrameTimeMs) {
            Start-Sleep -Milliseconds ([Math]::Floor($this.FrameTimeMs - $elapsed))
        }

        # Update FPS counter every second
        if (($now - $this.LastFPSUpdate).TotalSeconds -ge 1) {
            $this.CurrentFPS = $this.FrameCount
            $this.FrameCount = 0
            $this.LastFPSUpdate = $now
        }

        $this.LastFrame = Get-Date
    }
}

function Start-Loop {
	[Console]::CursorVisible = $false
	$terminalWidth = $host.UI.RawUI.WindowSize.Width
	$terminalHeight = $host.UI.RawUI.WindowSize.Height
	
	$frameTimer = [FrameTimer]::new(30)

	# Create RPG stats box on the right
	$statsWidth = 30
	$statsBox = [ConsoleBox]::new($terminalWidth - $statsWidth - 2, 1, $statsWidth, 20)
	$statsBox.BorderColor = "Cyan"

	# Create main game area box
	$gameBox = [ConsoleBox]::new(1, 1, $terminalWidth - $statsWidth - 4, $terminalHeight - 2)
	$gameBox.BorderColor = "White"

	# Draw static elements once
	Clear-Host
	$gameBox.DrawBox()
	$statsBox.DrawBox()
	
	# Display loading message
    $loadingMsg = @{
        Text = "The dwarfs are mining..."
        Color = "Yellow"
        BackgroundColor = "Black"
    }
    $gameBox.WriteContent(@($loadingMsg), 2)
	
	# Initialize managers
    $statsManager = [StatsManager]::new($statsBox)
    $mapManager = [MapManager]::new($gameBox)

	# Main loop
	while ($true) {
		# 1. Input handling
		if ([Console]::KeyAvailable) {
			$key = [Console]::ReadKey($true)
			switch ($key.Key) {
                "Escape" { return }
                "LeftArrow" { $mapManager.MovePlayer(-1, 0) }
                "RightArrow" { $mapManager.MovePlayer(1, 0) }
                "UpArrow" { $mapManager.MovePlayer(0, -1) }
                "DownArrow" { $mapManager.MovePlayer(0, 1) }
                # Example of using stats manager
                "H" { $statsManager.UpdateResourceStat("HP", ($statsManager.GetStat("HP").Current - 10), $statsManager.GetStat("HP").Max) }  # Test HP reduction
                "M" { $statsManager.UpdateResourceStat("MP", ($statsManager.GetStat("MP").Current - 5), $statsManager.GetStat("MP").Max) }   # Test MP reduction
                "X" { $statsManager.AddExperience(100) }  # Test experience gain
                "G" { $statsManager.ModifyGold(50) }      # Test gold gain
            }
		}

		# 3. Frame timing
		$frameTimer.WaitForNextFrame()
	}

	[Console]::CursorVisible = $true
	Clear-Host
}