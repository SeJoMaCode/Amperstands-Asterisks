# PowerShell Cellular Automata Dungeon Generator
function New-Grid {
    param (
        [int]$width,
        [int]$height,
        [double]$fillProbability
    )
    
    $grid = @()
    $random = New-Object Random
    
    for ($y = 0; $y -lt $height; $y++) {
        $row = @()
        for ($x = 0; $x -lt $width; $x++) {
            $row += if ($random.NextDouble() -lt $fillProbability) { 1 } else { 0 }
        }
        $grid += ,$row
    }
    
    return $grid
}

function Find-LargestRegion {
    param (
        [array]$grid
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $regions = New-Grid $width $height 0
    $regionSizes = @{}
    $regionId = 1
    
    function Flood-Fill {
        param (
            [array]$grid,
            [array]$regions,
            [int]$x,
            [int]$y,
            [int]$id
        )
        
        if ($x -lt 0 -or $x -ge $width -or $y -lt 0 -or $y -ge $height) { return 0 }
        if ($grid[$y][$x] -eq 1 -or $regions[$y][$x] -ne 0) { return 0 }
        
        $size = 1
        $regions[$y][$x] = $id
        
        $size += Flood-Fill $grid $regions ($x+1) $y $id
        $size += Flood-Fill $grid $regions ($x-1) $y $id
        $size += Flood-Fill $grid $regions $x ($y+1) $id
        $size += Flood-Fill $grid $regions $x ($y-1) $id
        
        return $size
    }
    
    # Find all regions
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            if ($grid[$y][$x] -eq 0 -and $regions[$y][$x] -eq 0) {
                $size = Flood-Fill $grid $regions $x $y $regionId
                $regionSizes[$regionId] = $size
                $regionId++
            }
        }
    }
    
    # Find largest region
    $largestRegion = 1
    $maxSize = 0
    foreach ($id in $regionSizes.Keys) {
        if ($regionSizes[$id] -gt $maxSize) {
            $maxSize = $regionSizes[$id]
            $largestRegion = $id
        }
    }
    
    # Keep only largest region
    $newGrid = New-Grid $width $height 1
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            if ($regions[$y][$x] -eq $largestRegion) {
                $newGrid[$y][$x] = 0
            }
        }
    }
    
    return $newGrid
}

function Smooth-Edges {
    param (
        [array]$grid,
        [int]$passes = 3  # Number of smoothing passes
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $currentGrid = Copy-Grid $grid

    # Do multiple passes of smoothing
    for ($pass = 0; $pass -lt $passes; $pass++) {
        $newGrid = Copy-Grid $currentGrid
        
        for ($y = 1; $y -lt $height-1; $y++) {
            for ($x = 1; $x -lt $width-1; $x++) {
                # Count immediate orthogonal neighbors (up, down, left, right)
                $orthNeighbors = 0
                if ($currentGrid[$y-1][$x] -eq 1) { $orthNeighbors++ }
                if ($currentGrid[$y+1][$x] -eq 1) { $orthNeighbors++ }
                if ($currentGrid[$y][$x-1] -eq 1) { $orthNeighbors++ }
                if ($currentGrid[$y][$x+1] -eq 1) { $orthNeighbors++ }

                # Count all neighbors (including diagonals)
                $allNeighbors = Get-NeighborCount $currentGrid $x $y

                # Smoothing rules
                if ($currentGrid[$y][$x] -eq 1) {
                    # Remove single walls and dead ends
                    if ($orthNeighbors -le 1 -or $allNeighbors -le 2) {
                        $newGrid[$y][$x] = 0
                    }
                } else {
                    # Fill tight corners and single-tile gaps
                    if ($allNeighbors -ge 6 -or $orthNeighbors -ge 3) {
                        $newGrid[$y][$x] = 1
                    }
                }
            }
        }
        $currentGrid = $newGrid
    }
    
    return $currentGrid
}

function Copy-Grid {
    param (
        [array]$grid
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $newGrid = @()
    
    for ($y = 0; $y -lt $height; $y++) {
        $row = @()
        for ($x = 0; $x -lt $width; $x++) {
            $row += $grid[$y][$x]
        }
        $newGrid += ,$row
    }
    
    return $newGrid
}

function Get-NeighborCount {
    param (
        [array]$grid,
        [int]$x,
        [int]$y
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $count = 0
    
    for ($i = -1; $i -le 1; $i++) {
        for ($j = -1; $j -le 1; $j++) {
            if ($i -eq 0 -and $j -eq 0) { continue }
            
            $newX = $x + $i
            $newY = $y + $j
            
            if ($newX -lt 0 -or $newX -ge $width -or $newY -lt 0 -or $newY -ge $height) {
                $count++
            }
            elseif ($grid[$newY][$newX] -eq 1) {
                $count++
            }
        }
    }
    
    return $count
}

function Step-CellularAutomata {
    param (
        [array]$grid,
        [int]$birthLimit = 4,
        [int]$deathLimit = 4
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $newGrid = Copy-Grid $grid
    
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $neighbors = Get-NeighborCount $grid $x $y
            
            if ($grid[$y][$x] -eq 1) {
                $newGrid[$y][$x] = if ($neighbors -lt $deathLimit) { 0 } else { 1 }
            }
            else {
                $newGrid[$y][$x] = if ($neighbors -gt $birthLimit) { 1 } else { 0 }
            }
        }
    }
    
    return $newGrid
}

function Add-BorderWalls {
    param (
        [array]$grid
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    $newGrid = Copy-Grid $grid
    
    # Add top and bottom walls
    for ($x = 0; $x -lt $width; $x++) {
        $newGrid[0][$x] = 1
        $newGrid[$height-1][$x] = 1
    }
    
    # Add left and right walls
    for ($y = 0; $y -lt $height; $y++) {
        $newGrid[$y][0] = 1
        $newGrid[$y][$width-1] = 1
    }
    
    return $newGrid
}

function Show-Grid {
    param (
        [array]$grid
    )
    
    $height = $grid.Length
    $width = $grid[0].Length
    
    for ($y = 0; $y -lt $height; $y++) {
        $line = ""
        for ($x = 0; $x -lt $width; $x++) {
            $line += if ($grid[$y][$x] -eq 1) { "#" } else { "." }
        }
        Write-Host $line
    }
}

function New-Dungeon {
    param (
        [int]$width = 50,
        [int]$height = 30,
        [double]$fillProbability = 0.45,
        [int]$iterations = 4
    )
    
    # Initialize random grid
    $grid = New-Grid $width $height $fillProbability
		
	# Add border walls
    $grid = Add-BorderWalls $grid
    
    # Run cellular automata iterations
    for ($i = 0; $i -lt $iterations; $i++) {
        $grid = Step-CellularAutomata $grid
    }
	    
    # Find and keep only the largest connected region
    $grid = Find-LargestRegion $grid
    
    # Smooth edges with multiple passes
    $grid = Smooth-Edges $grid 3  # 3 passes of smoothing
    
    return $grid
}

# Generate and display a dungeon
# $dungeon = New-Dungeon -width 120 -height 50
# Show-Grid $dungeon

# Example usage:
# $dungeon = New-Dungeon -width 40 -height 25 -fillProbability 0.4 -iterations 5
# Show-Grid $dungeon