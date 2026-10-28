--------------------
---- ANIMATIONS ----
--------------------

-- Curves
hl.curve("eventHorizon", { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("singularity",  { type = "bezier", points = { {0.7, 0},     {0.84, 0}    } })
hl.curve("gravity",      { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.curve("pull",         { type = "spring", mass = 1, stiffness = 420, dampening = 32 })

-- Global
hl.animation({ leaf = "global",        enabled = true, speed = 10,  bezier = "default" })

-- Windows
hl.animation({ leaf = "windows",       enabled = true, speed = 3,   spring = "pull" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3,   spring = "pull",         style = "popin 25%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.2, bezier = "singularity",  style = "popin 15%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 2.8, spring = "pull" })

-- Fades
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.8, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.6, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 2.5, bezier = "quick" })

-- Borders
hl.animation({ leaf = "border",        enabled = true, speed = 3,   bezier = "eventHorizon" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })

-- Layers
hl.animation({ leaf = "layers",        enabled = true, speed = 3,   bezier = "eventHorizon" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.5, bezier = "eventHorizon", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2,   bezier = "singularity",  style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.6, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, bezier = "almostLinear" })

-- Workspaces
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.5, bezier = "gravity", style = "slidefade 8%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2.5, bezier = "gravity", style = "slidefade 8%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.5, bezier = "gravity", style = "slidefade 8%" })

hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 5,   bezier = "quick" })