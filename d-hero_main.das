require daslib/media
require daslib/decs_boost
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

var gameScore = 0;
var gameCombo = 0;
var gameTime: float;
var gameItemsLeft = 0;

let 
    actionKeyQ = 0
    actionKeyW = 1
    actionKeyE = 2
    actionKeyR = 3
    actionKeyU = 4
    actionKeyI = 5
    actionKeyO = 6            
    actionKeyP = 7

let 
    actionKeyTxtMapping = [[auto "Q"; "W"; "E"; "R"; "U"; "I"; "O"; "P"]]
var
    actionKeyProcessed = [[auto false; false; false; false; false; false; false; false]]

let
    actionTimelineWith = 6.0f
    actionEarlyHint = 1.3f
    actionGoodWindow = 0.7f
    actionPerfectWindow = 0.3f
    gameActionGoodScore = 25
    gameActionPerfectScore = 50
    actionXOffset = 0.2f
    actionXHint = 16.0f
    actionYSz = 600.0f
    actionYLines = 8.0f

var 
    RAND_SEED: int4
    drawVelBump: float2

//timer auto-delete

[decs_template]
struct AutoDeleteTimePassed
    lifetime: float
    eid: EntityId

[decs(stage = update)]
def upd_AutoDeleteTimePassed(var p: AutoDeleteTimePassed)
    let dt = get_delta_time()
    p.lifetime -= dt;
    if (p.lifetime < 0.0f)
        delete_entity(p.eid)

// action timeline marks

[decs_template]
struct LevelActionPoint
    atype: int
    period: float2
    params: float2
    key: int
    triggered: bool

def isActionKeyDown(var key)
    if (
        ((key == actionKeyQ) && get_key(VK_Q)) ||
        ((key == actionKeyW) && get_key(VK_W)) ||
        ((key == actionKeyE) && get_key(VK_E)) ||
        ((key == actionKeyR) && get_key(VK_R)) ||
        ((key == actionKeyU) && get_key(VK_U)) ||
        ((key == actionKeyI) && get_key(VK_I)) ||
        ((key == actionKeyO) && get_key(VK_O)) ||
        ((key == actionKeyP) && get_key(VK_P))
    )
        return true
    return false

def actionKeyToOffset(var key)
    if key == actionKeyQ
        return 0.0f
    elif key == actionKeyW
        return 1.0f
    elif key == actionKeyE
        return 2.0f
    elif key == actionKeyR
        return 3.0f
    elif key == actionKeyU
        return 4.0f
    elif key == actionKeyI
        return 5.0f
    elif key == actionKeyO
        return 6.0f
    elif key == actionKeyP
        return 7.0f
    return -1.0f

[decs(stage = update)]
def upd_LevelActionPoint(var p: LevelActionPoint)
    let xScale = float(get_screen_width()) / actionTimelineWith
    let yBase = float(get_screen_height()) - actionYSz;
    let ySzLine = actionYSz / actionYLines

    if p.triggered
        return

    let perY = p.period.y == 0.0f ? p.period.x + actionPerfectWindow : p.period.y
    let rx = p.period.x - gameTime
    let lx = perY - gameTime

    let hintCmp = rx

    if hintCmp > actionEarlyHint
        return 

    var keyTriggered = isActionKeyDown(p.key)

    if keyTriggered && !actionKeyProcessed[p.key]
        actionKeyProcessed[p.key] = true
    else
        keyTriggered = false

    let popupPos = float2(xScale * (rx + actionXOffset * 1.5f), yBase - 32.0f)

    if keyTriggered
        if hintCmp < actionGoodWindow
            gameCombo += 1
            if hintCmp < actionPerfectWindow
                mkActionTriggeredPopup(popupPos, 1.5f, 0)
                gameScore += gameActionPerfectScore
            else
                mkActionTriggeredPopup(popupPos, 1.0f, 1)
                gameScore += gameActionGoodScore
        else
            mkActionTriggeredPopup(popupPos, -1.0f, 2)
            gameCombo = 0
        p.triggered = true
        --gameItemsLeft
    elif hintCmp < 0.0f
        mkActionTriggeredPopup(popupPos, -1.0f, 3)
        gameCombo = 0
        p.triggered = true
        --gameItemsLeft

[decs(stage = draw)]
def draw_LevelActionPoint(var p: LevelActionPoint; var eid: EntityId)
    let perY = p.period.y == 0.0f ? p.period.x + actionPerfectWindow*1.0f : p.period.y
    let rx = p.period.x - gameTime
    let lx = perY - gameTime

    if (rx > actionTimelineWith) || p.triggered
        return

    let xScale = float(get_screen_width()) / actionTimelineWith
    let yBase = float(get_screen_height()) - actionYSz;
    let ySzLine = actionYSz / actionYLines
    
    let yIdx = actionKeyToOffset(p.key);
    
    let badColor = float3(1.0f, 0.0f, 0.0f)
    let goodColor = float3(0.0f, 1.0f, 0.0f)
    let perfectColor = float3(0.0f, 0.0f, 1.0f)
    var hintColor = badColor//lerp(badColor, goodColor, -(actionEarlyHint - rx) / (actionEarlyHint - actionGoodWindow))

    let hintCmp = rx

    if hintCmp <= 0.0f
        hintColor = badColor
        return 
    if hintCmp < actionGoodWindow
        hintColor = lerp(goodColor, perfectColor, (actionGoodWindow - rx) / (actionGoodWindow - actionPerfectWindow))
    elif hintCmp < actionEarlyHint
        hintColor = lerp(badColor, goodColor, (actionEarlyHint - rx) / (actionEarlyHint - actionGoodWindow))

    fill_rect(xScale * (rx + actionXOffset), yBase + ySzLine * yIdx, xScale*(lx-rx), ySzLine, make_color(hintColor.x, hintColor.y, hintColor.z))

    if hintCmp < actionEarlyHint && rx > 0.0f
        let xOverlap = 0.1f
        let yOverlapScale = 32.0f
        let yOverlap = (hintCmp / actionEarlyHint) * yOverlapScale
        //fill_rect(xScale * actionXOffset, yBase + ySzLine * yIdx - yOverlap, xScale*xOverlap, ySzLine + yOverlap*2.0f, 0x00AAFF)

    set_font_name("mono")
    set_font_size(ySzLine - 4.0f)
    let keyTxt = actionKeyTxtMapping[p.key]
    text_out(xScale * (rx + actionXOffset), yBase + ySzLine * yIdx, "{keyTxt}", make_color(1.0))

//level dependant

var currentLevelIndex = 0;

[decs_template]
struct LevelDependantObj
    eid: EntityId
    lvidx: int

[decs(stage = update)]
def upd_LevelDependantObj(var p: LevelDependantObj)
    if p.lvidx != currentLevelIndex
        delete_entity(p.eid)

//

[decs_template]
struct ActionTriggeredPopup
    pos: float2
    vel: float2
    stype: int

def mkActionTriggeredPopup(var pos: float2; var yvmul: float; var ltype: int)
    var rvel = float2(0.0f, -yvmul)
    var rndf = random_float4(RAND_SEED).xy * float2(0.6f, 0.5f);

    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[ActionTriggeredPopup pos = pos, vel = (rvel + rndf) * 10.0f, stype = ltype]])
        apply_decs_template(cmp, [[LevelDependantObj eid = eid, lvidx = currentLevelIndex ]])
        apply_decs_template(cmp, [[AutoDeleteTimePassed eid = eid, lifetime = 0.7f ]]) 

[decs(stage = update)]
def upd_ActionTriggeredPopup(var p: ActionTriggeredPopup)
    let dt = get_delta_time()
    p.pos += p.vel * dt;

[decs(stage = draw)]
def draw_ActionTriggeredPopup(var p: ActionTriggeredPopup)
    set_font_name("mono")
    set_font_size(15)

    var rstr = "WTF?";
    if (p.stype == 0)
        rstr = "Perfect"
    elif (p.stype == 1)
        rstr = "Good"
    elif (p.stype == 2)
        rstr = "Bad"
    elif (p.stype == 3)
        rstr = "Missed"
    else
        rstr = "WTF #2?"

    text_out(p.pos.x, p.pos.y, "{rstr}", 0xFF44AA)

//FPS drawer

[decs_template]
struct FPSTracker
    fps: int

def mkFPSTracker()
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[FPSTracker fps = 0]])


[decs(stage = update)]
def upd_FPSTracker(var p: FPSTracker)
    p.fps = roundi(1.0f / get_delta_time());

[decs(stage = draw)]
def draw_FPSTracker(var p: FPSTracker)
    set_font_name("mono")
    set_font_size(15)
    text_out(get_screen_width() - 100, get_screen_height() - 18, "FPS: {p.fps}", make_color(1.0))

//ECS -

var 
    levels: array<array<LevelActionPoint>>
    paused = true
    menuSel = 0
    levelSel = 0

let
    menuItemsCnt = 3

def drawActionUi
    let xScale = float(get_screen_width()) / actionTimelineWith
    let yBase = float(get_screen_height()) - actionYSz;
    let ySzLine = actionYSz / actionYLines

    for yIdx_i in range(0, int(actionYLines))
        let yIdx = float(yIdx_i)
        line(0.0f, yBase + ySzLine * yIdx, float(get_screen_width()), yBase + ySzLine * yIdx, 0xFFFFFF)

    line(xScale * actionXOffset, yBase, xScale * actionXOffset, yBase + ySzLine * actionYLines, 0xFFFFFF)
    line(xScale * (actionXOffset + actionPerfectWindow), yBase, xScale * (actionXOffset + actionPerfectWindow), yBase + ySzLine * actionYLines, 0xFFFFFF)
    line(xScale * (actionXOffset + actionGoodWindow), yBase, xScale * (actionXOffset + actionGoodWindow), yBase + ySzLine * actionYLines, 0xFFFFFF)
    line(xScale * (actionXOffset + actionEarlyHint), yBase, xScale * (actionXOffset + actionEarlyHint), yBase + ySzLine * actionYLines, 0xFFFFFF)

def mkLevelDatas()
    resize(levels, 3)
    clear(levels[0])
    clear(levels[1])
    clear(levels[2])

    //HOWTO

    //           level number
    //            | 
    //push(levels[0], [[LevelActionPoint period = float2(003.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    //                                                     |                                                        |
    //                                                   start time                                             key that will be used
    //other can be ommited                                                

    //level 0

    //relative timings
	var atime = 2.0f
    push(levels[0], [[LevelActionPoint period = float2(atime, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
	atime += 0.5f//how much to move

    push(levels[0], [[LevelActionPoint period = float2(004.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[0], [[LevelActionPoint period = float2(003.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[0], [[LevelActionPoint period = float2(005.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])

    //level 1

    push(levels[1], [[LevelActionPoint period = float2(004.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(004.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(005.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(005.600f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(006.800f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(007.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(008.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(008.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[1], [[LevelActionPoint period = float2(008.600f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(008.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(009.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(009.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(010.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(010.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(010.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(011.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(011.800f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(012.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[1], [[LevelActionPoint period = float2(012.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(012.400f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(012.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(013.100f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(013.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(013.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(013.700f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(014.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[1], [[LevelActionPoint period = float2(014.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(014.400f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(014.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(015.100f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(015.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(015.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(015.700f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(015.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(016.300f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])
    push(levels[1], [[LevelActionPoint period = float2(016.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[1], [[LevelActionPoint period = float2(016.700f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyQ]])
    push(levels[1], [[LevelActionPoint period = float2(016.900f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])
    push(levels[1], [[LevelActionPoint period = float2(017.200f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyW]])

    //level 2
    for i in range(0,100)
        push(levels[2], [[LevelActionPoint period = float2(003.000f + float(i)*0.8f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyP]])
    push(levels[2], [[LevelActionPoint period = float2(003.500f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyE]])
    push(levels[2], [[LevelActionPoint period = float2(005.000f, 000.000f), params = float2(100.000f, 000.000f), key = actionKeyR]])

def restartLevel()
    //mkDrawPointer()
    gameScore = 0
    gameCombo = 0
    gameTime = 0.0f

    for i in levels[currentLevelIndex]
        ++gameItemsLeft
        create_entity <| @ ( eid, cmp )
            cmp |> set("eid", eid)
            var copy = i;
            apply_decs_template(cmp, copy)
            apply_decs_template(cmp, [[LevelDependantObj eid = eid, lvidx = currentLevelIndex ]])

    
[export]
def initialize(is_hard_reload: bool)
    set_window_title("Patterns")
    set_antialiasing(4)
    randomize_seed(RAND_SEED)

    if empty(levels)
        mkLevelDatas()

    if is_hard_reload
        mkFPSTracker()
        paused = true
        menuSel = 0
        currentLevelIndex = 0
        gameScore = 0
        gameTime = 0.0f

def restartLevelFromMenu()
    var oldLvIdx = currentLevelIndex
    currentLevelIndex = -1
    decs_stage("update")
    currentLevelIndex = -2
    decs_stage("update")
    currentLevelIndex = oldLvIdx
    decs_stage("update")
    if menuSel == 1
        currentLevelIndex = levelSel
    restartLevel()

[export]
def act(dt: float)
    if get_key_press(VK_ESCAPE)
        paused = !paused

    if paused
        if get_key_press(VK_RETURN)
            if (menuSel == 0) || (menuSel == 1)
                //sort-of-hack
                var oldLvIdx = currentLevelIndex
                restartLevelFromMenu()
                paused = false
            elif menuSel == 2
                schedule_quit_game()
            menuSel = 0
        if get_key_press(VK_RIGHT) || get_key_press(VK_D)
            levelSel += 1
            if levelSel >= length(levels)
                levelSel = 0
        if get_key_press(VK_LEFT) || get_key_press(VK_A)
            levelSel -= 1
            if levelSel < 0
                levelSel = length(levels)-1
        if get_key_press(VK_UP) || get_key_press(VK_W)
            menuSel -= 1
            if menuSel < 0
                menuSel = menuItemsCnt-1
        if get_key_press(VK_DOWN) || get_key_press(VK_S)
            menuSel += 1
            if menuSel >= menuItemsCnt 
                menuSel = 0
        return

    gameTime += dt

    for i in range(0,8)
        if actionKeyProcessed[i]
            if !isActionKeyDown(i)
                actionKeyProcessed[i] = false

    decs_stage("update")
    commit()

    if (gameItemsLeft == 0)
        if get_key_press(VK_RETURN)
            if length(levels)-1 > currentLevelIndex
                ++currentLevelIndex
            else
                currentLevelIndex = 0
            restartLevelFromMenu()


[export]
def draw
    set_font_name("mono")
    set_font_size(15)

    text_out(get_screen_width()-256, 0, "Score: {gameScore}", 0xFFFFFF)
    text_out(get_screen_width()-256, 20, "Combo: {gameCombo}", 0xFFFFFF)
    text_out(0, 0, "Level: {currentLevelIndex}", 0xFFFFFF)

    if paused
        let activeColor = 0xFFFFFF
        let inactiveColor = 0x777777
        set_font_size(25)
        text_out(get_screen_width()/2, get_screen_height()/2, "Restart", menuSel == 0 ? activeColor : inactiveColor)
        text_out(get_screen_width()/2, get_screen_height()/2 + 30, "< Change level to {levelSel} >", menuSel == 1 ? activeColor : inactiveColor)
        text_out(get_screen_width()/2, get_screen_height()/2 + 60, "Exit", menuSel == 2 ? activeColor : inactiveColor)
    else
        decs_stage("draw")
        if gameItemsLeft > 0
            drawActionUi()
        else
            if length(levels)-1 > currentLevelIndex
                text_out(get_screen_width()/2, get_screen_height()/2, "Level completed! Hit <Enter> for next level", 0xFFFFFF)
            else
                text_out(get_screen_width()/2, get_screen_height()/2, "Level completed! Hit <Enter> to start over", 0xFFFFFF)
