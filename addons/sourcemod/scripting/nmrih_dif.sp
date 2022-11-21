#pragma newdecls required
#pragma semicolon 1

#include <sdktools>
#include <sdkhooks>
#include <globalvariables>
#include <getoverit>

#define VOTE_NEEDED 0.74

enum GameMode {
    GameModeDefault,
    GameModeRunner,
    GameModeKid
};

enum GameDif {
    GameDifClassic,
    GameDifCasual,
    GameDifNightmare
}

enum GameDensity {
    GameDensity10,
    GameDensity15,
    GameDensity30,
    GameDensity50,
    GameDensityCustom
}

char szGameMode[][] = { "ModeMenuItemDefault", "ModeMenuItemRunner", "ModeMenuItemKid" };
char szGameDif[][] = { "DifMenuItemClassic", "DifMenuItemCasual", "DifMenuItemNightmare" };

ConVar hostname,
    sv_max_runner_chance,
    ov_runner_chance,
    ov_runner_kid_chance,

    sm_kidchance_classic,
    sm_kidchance_nightmare,

    sm_inf_stamina,
    sm_machete_enable,
    sm_record_enable_rt,

    sm_dif_enable,
    sm_gamemode_default,
    sm_gamemode,
    sv_difficulty,
    sv_spawn_density;

bool g_bEnabled, g_bListenClient[MAXPLAYERS];

float sv_max_runner_chance_default,
    ov_runner_chance_default,
    ov_runner_kid_chance_default,
    g_fKidChance,
    g_fDensity[MAXPLAYERS];

char g_szVoteCommand[MAXPLAYERS][128],
    g_szVoteHint[MAXPLAYERS][256],
    g_szVoteFinishHint[MAXPLAYERS][64],
    g_szVoteTitle[MAXPLAYERS][64];

int g_iVoteClient;
GameMode g_GameMode = GameModeDefault;
GameDif g_GameDif = GameDifClassic;
GameDensity g_GameDensity = GameDensity15;

Menu g_hConfirmLast[MAXPLAYERS],
    g_hTopMenu,
    g_hModeMenu,
    g_hDifMenu,
    g_hDensityMenu,
    g_hConfirmMenu,
    g_hVoteMenu;

public Plugin myinfo = {
    name		= "[NMRiH] Difficult Moder",
    author		= "clagura",
    description	= "Allow player the change difficult and mode.",
    version		= "1.0.3",
    url			= "https://steamcommunity.com/id/wwwttthhh/"
}

public void OnPluginStart() {
    LoadTranslations("nmrih.dif.phrases");
    hostname = FindConVar("hostname");

    sv_max_runner_chance = FindConVar("sv_max_runner_chance");
    ov_runner_chance = FindConVar("ov_runner_chance");
    ov_runner_kid_chance = FindConVar("ov_runner_kid_chance");
    
    (sm_dif_enable = CreateConVar("sm_dif_enable", "1", "Enable/Disable plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_bEnabled = sm_dif_enable.BoolValue;

    (sm_gamemode_default = CreateConVar("sm_gamemode_default", "1", "sm_gamemode's default value", 0, true, 0.0, true, 2.0)).AddChangeHook(OnConVarChange);
    (sm_gamemode = CreateConVar("sm_gamemode", "1", "0 - default gamemode, 1 - All runners, 2 - All kids", 0, true, 0.0, true, 2.0)).AddChangeHook(OnConVarChange);

    (sm_kidchance_classic = CreateConVar("sm_kidchance_classic", "0.3", "Kid chance in classic difficulty.", FCVAR_NOTIFY, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    (sm_kidchance_nightmare = CreateConVar("sm_kidchance_nightmare", "0.15", "Kid chance in nightmare difficulty.", FCVAR_NOTIFY, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);

    (sv_difficulty = FindConVar("sv_difficulty")).AddChangeHook(OnConVarChange);
    (sv_spawn_density = FindConVar("sv_spawn_density")).AddChangeHook(OnConVarChange);
    g_GameMode = view_as<GameMode>(sm_gamemode.IntValue);

    AutoExecConfig();
    MenuInitialize();

    //Reg Cmd
    RegConsoleCmd("sm_dif", CmdTopMenu);
    AddCommandListener(DensityListener, "say");

    for (int i = 0; i < MAXPLAYERS; i++) {
        g_bListenClient[i] = false;
    }
    
    RegConsoleCmd("sm_difshow", GameInfoShowToClient);
    HookEvent("nmrih_round_begin", OnRoundStart);
}

public void OnMapStart() {
    sm_gamemode.FloatValue = sm_gamemode_default.FloatValue;
    g_GameMode = view_as<GameMode>(sm_gamemode_default.IntValue);
}

public void OnRoundStart(Event e, const char[] n, bool b) {
    ConVarSet(g_GameMode);
    CreateTimer(1.0, TimerShowGameInfo);
}

Action TimerShowGameInfo (Handle timer) {
    GameInfoShowToClient(0, 0);
    return Plugin_Stop;
}

public void OnConfigsExecuted() {
    sm_inf_stamina = FindConVar("sm_inf_stamina");
    sm_machete_enable = FindConVar("sm_machete_enable");
    sm_record_enable_rt = FindConVar("sm_record_enable_rt");

    sv_max_runner_chance_default = sv_max_runner_chance.FloatValue;
    ov_runner_chance_default = ov_runner_chance.FloatValue;
    ov_runner_kid_chance_default = ov_runner_kid_chance.FloatValue;

    sm_gamemode.IntValue = sm_gamemode_default.IntValue;
    g_GameMode = view_as<GameMode>(sm_gamemode.IntValue);
    ConVarSet(g_GameMode);

    SetDifficulty();
}

public void OnConVarChange(ConVar CVar, const char[] oldValue, const char[] newValue) {
    if (!g_bEnabled) return;
    if (CVar == sm_dif_enable) {
        g_bEnabled = sm_dif_enable.BoolValue;
    }
    else if (CVar == sm_gamemode) {
        g_GameMode = view_as<GameMode>(sm_gamemode.IntValue);
        if (g_GameMode == GameModeRunner || g_GameMode == GameModeKid) {
            ShamblerConvertToRunner(g_GameMode == GameModeKid);
        }
        ConVarSet(g_GameMode);
    }
    else if (CVar == sv_difficulty || CVar == sv_spawn_density) {
        SetDifficulty();
    }
    else if (CVar == sm_kidchance_classic && g_GameDif != GameDifNightmare) {
        g_fKidChance = sm_kidchance_classic.FloatValue;
        ov_runner_chance.FloatValue = g_fKidChance;
    }
    else if (CVar == sm_kidchance_nightmare && g_GameDif == GameDifNightmare) {
        g_fKidChance = sm_kidchance_nightmare.FloatValue;
        ov_runner_chance.FloatValue = g_fKidChance;
    }
}

void SetDifficulty() {
    char szBuffer[128], szHostName[128], szDifficulty[24];
    hostname.GetString(szBuffer, sizeof(szBuffer));
    if (SplitString(szBuffer, "（", szHostName, 100) == -1) {
        strcopy(szHostName, 100, szBuffer);
    }
    
    sv_difficulty.GetString(szBuffer, 128);
    if (StrEqual(szBuffer, "classic")) {
        g_GameDif = GameDifClassic;
        g_fKidChance = sm_kidchance_classic.FloatValue;
        FormatEx(szDifficulty, 24, "经典");
    }
    else if (StrEqual(szBuffer, "casual")) {
        g_GameDif = GameDifCasual;
        g_fKidChance = sm_kidchance_classic.FloatValue;
        FormatEx(szDifficulty, 24, "休闲");
    }
    else if (StrEqual(szBuffer, "nightmare")) {
        g_GameDif = GameDifNightmare;
        g_fKidChance = sm_kidchance_nightmare.FloatValue;
        FormatEx(szDifficulty, 24, "噩梦");
    }

    float fDensity = sv_spawn_density.FloatValue;
    if (fDensity == 1.5) {
        g_GameDensity = GameDensity15;
    }
    else if (fDensity == 3.0) {
        g_GameDensity = GameDensity30;
    }
    else if (fDensity == 5.0) {
        g_GameDensity = GameDensity50;
    }
    else {
        g_GameDensity = GameDensityCustom;
    }
    
    FormatEx(szBuffer, 128, "%s（%.1f倍%s）", szHostName, fDensity, szDifficulty);
    hostname.SetString(szBuffer);
}

public void OnPluginEnd() {
    delete g_hTopMenu, g_hModeMenu, g_hDifMenu, g_hDensityMenu, g_hConfirmMenu, g_hVoteMenu;
    ConVarSet(GameModeDefault); // Reset convar
}

public void OnEntityCreated(int iEntity, const char[] classname) {
    if(!g_bEnabled || g_GameMode == GameModeDefault) return;

    if(IsValidShamblerZombie(iEntity))
        SDKHook(iEntity, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);
}

bool IsValidShamblerZombie(int iEntity) {
    char szClassname[128];
    if (GetEntityClassname(iEntity, szClassname, sizeof(szClassname))) {
        return StrEqual(szClassname, "npc_nmrih_shamblerzombie", false);
    }
    return false;
}

public void SDKHookCBZombieSpawnPost(int zombie) {
    switch(g_GameMode)
    {
        case GameModeRunner:	ShamblerToRunnerFromPosion(zombie);
        case GameModeKid:	ShamblerToRunnerFromPosion(zombie, true);
    }
}

int ShamblerToRunnerFromPosion(int iZombie, bool isKid = false) {
    float fPos[3];
    GetEntPropVector(iZombie, Prop_Send, "m_vecOrigin", fPos);
    SDKUnhook(iZombie, SDKHook_SpawnPost, SDKHookCBZombieSpawnPost);

    if (isKid || GetRandomInt(0, 100) < 100 * g_fKidChance) {
        AcceptEntityInput(iZombie, "kill");
        iZombie = CreateEntityByName("npc_nmrih_kidzombie");

        if(!IsValidEntity(iZombie))
            return -1;
        if(DispatchSpawn(iZombie))
            TeleportEntity(iZombie, fPos, NULL_VECTOR, NULL_VECTOR);
    }
    else {
        AcceptEntityInput(iZombie, "BecomeRunner");
    }
    return iZombie;
}

void ShamblerConvertToRunner(bool bKid=false) {
    int nMaxEnts = GetMaxEntities();
    for(int iZombie = MaxClients + 1; iZombie <= nMaxEnts; iZombie++)
    {
        if(IsValidShamblerZombie(iZombie))
            ShamblerToRunnerFromPosion(iZombie, bKid);
    }
}

void ConVarSet(GameMode mode) {
    switch(mode)
    {
        case GameModeRunner:
        {
            sv_max_runner_chance.FloatValue = 3.0;
            ov_runner_chance.FloatValue = 3.0;
            ov_runner_kid_chance.FloatValue = g_fKidChance;
        }
        case GameModeKid:
        {
            sv_max_runner_chance.FloatValue = 3.0;
            ov_runner_chance.FloatValue = 3.0;
            ov_runner_kid_chance.FloatValue = 1.0;
        }
        case GameModeDefault:
        {
            sv_max_runner_chance.FloatValue = sv_max_runner_chance_default;
            ov_runner_chance.FloatValue = ov_runner_chance_default;
            ov_runner_kid_chance.FloatValue = ov_runner_kid_chance_default;
        }
    }
}

void MenuInitialize() {
    // Top Menu

    g_hTopMenu = new Menu(TopMenuHandler, MenuAction_DisplayItem | MenuAction_Select | MenuAction_Display); 
    g_hTopMenu.SetTitle("TopMenuTitle");

    //g_hTopMenu.AddItem("TopMenuItemMode", "TopMenuItemMode", ITEMDRAW_DISABLED);
    g_hTopMenu.AddItem("TopMenuItemMode", "TopMenuItemMode");
    g_hTopMenu.AddItem("TopMenuItemDifficulty", "TopMenuItemDifficulty");
    g_hTopMenu.AddItem("TopMenuItemDensity", "TopMenuItemDensity");
    g_hTopMenu.AddItem("TopMenuItemInfStamina", "TopMenuItemInfStamina");
    g_hTopMenu.AddItem("TopMenuItemMachete", "TopMenuItemMachete");

    g_hTopMenu.ExitButton = true;

    // Mode Menu

    g_hModeMenu = new Menu(ModeMenuHandler, MenuAction_DisplayItem | MenuAction_Select | MenuAction_Display | MenuAction_Cancel | MenuAction_DrawItem);
    g_hModeMenu.SetTitle("ModeMenuTitle");

    g_hModeMenu.AddItem("ModeMenuItemDefault", "ModeMenuItemDefault");
    g_hModeMenu.AddItem("ModeMenuItemRunner", "ModeMenuItemRunner");
    g_hModeMenu.AddItem("ModeMenuItemKid", "ModeMenuItemKid");

    g_hModeMenu.ExitBackButton = true;

    // Dif Menu

    g_hDifMenu = new Menu(DifMenuHandler, MenuAction_DisplayItem | MenuAction_Select | MenuAction_Display | MenuAction_Cancel | MenuAction_DrawItem);
    g_hDifMenu.SetTitle("DifMenuTitle");

    g_hDifMenu.AddItem("DifMenuItemClassic", "DifMenuItemClassic");
    g_hDifMenu.AddItem("DifMenuItemCasual", "DifMenuItemCasual");
    g_hDifMenu.AddItem("DifMenuItemNightmare", "DifMenuItemNightmare");

    g_hDifMenu.ExitBackButton = true;

    // Density Menu

    g_hDensityMenu = new Menu(DensityMenuHandler, MenuAction_DisplayItem | MenuAction_Select | MenuAction_Display | MenuAction_Cancel | MenuAction_DrawItem);
    g_hDensityMenu.SetTitle("DensityMenuTitle");
    
    g_hDensityMenu.AddItem("1.0", "1.0");
    g_hDensityMenu.AddItem("1.5", "1.5");
    g_hDensityMenu.AddItem("3.0", "3.0");
    g_hDensityMenu.AddItem("5.0", "5.0");
    g_hDensityMenu.AddItem("DensityMenuItemCustom", "DensityMenuItemCustom");

    g_hDensityMenu.ExitBackButton = true;

    // Confirm Menu

    g_hConfirmMenu = new Menu(ConfirmMenuHandler, MenuAction_DisplayItem | MenuAction_Select | MenuAction_Display | MenuAction_Cancel);
    g_hConfirmMenu.AddItem("Yes", "Yes");
    g_hConfirmMenu.AddItem("No", "No");

    g_hConfirmMenu.ExitBackButton = true;

    // Vote Menu

    g_hVoteMenu = new Menu(VoteMenuHandler, MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteEnd | MenuAction_VoteCancel);
    g_hVoteMenu.AddItem("Yes", "Yes");
    g_hVoteMenu.AddItem("No", "No");

    g_hVoteMenu.ExitButton = true;
}

public Action CmdTopMenu(int client, int args) {
    if (!g_bEnabled) {
        CPrintToChat(client, 0, "{red}%t %t", "ChatFlag", "ModeDisable");
        return Plugin_Handled;
    }
    g_hTopMenu.Display(client, 20);
    return Plugin_Handled;
}

int TopMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        FormatEx(buffer, 64, "%T", "TopMenuTitle", param1);
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_Select) {
        switch (param2) {
            case 0: {
                g_hModeMenu.Display(param1, 20);
            }
            case 1: {
                g_hDifMenu.Display(param1, 20);
            }
            case 2: {
                g_hDensityMenu.Display(param1, 20);
            }
            case 3: {
                if (sm_inf_stamina == null) {
                    CPrintToChat(param1, 0, "{red}%t %t", "ChatFlag", "InfStaminaInvalid");
                    g_hTopMenu.Display(param1, 20);
                    return 0;
                }
                if (sm_inf_stamina.IntValue <= 0) {
                    FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_inf_stamina 1");
                    FormatEx(g_szVoteTitle[param1 - 1], 64, "InfStaminaEnableVoteTitle");
                    FormatEx(g_szVoteHint[param1 - 1], 256, "InfStaminaEnableVoteHint");
                    FormatEx(g_szVoteFinishHint[param1 - 1], 64, "InfStaminaEnableVoteFinishHint");
                }
                else {
                    FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_inf_stamina 0");
                    FormatEx(g_szVoteTitle[param1 - 1], 64, "InfStaminaDisableVoteTitle");
                    FormatEx(g_szVoteHint[param1 - 1], 256, "InfStaminaDisableVoteHint");
                    FormatEx(g_szVoteFinishHint[param1 - 1], 64, "InfStaminaDisableVoteFinishHint");
                }
                g_hConfirmMenu.Display(param1, 20);
                g_hConfirmLast[param1 -1] = menu;
            }
            case 4: {
                if (sm_machete_enable == null) {
                    CPrintToChat(param1, 0, "{red}%t %t", "ChatFlag", "MacheteInvalid");
                    g_hTopMenu.Display(param1, 20);
                    return 0;
                }
                if (sm_machete_enable.IntValue <= 0) {
                    FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_machete_enable 1");
                    FormatEx(g_szVoteTitle[param1 - 1], 64, "MacheteEnableVoteTitle");
                    FormatEx(g_szVoteHint[param1 - 1], 256, "MacheteEnableVoteHint");
                    FormatEx(g_szVoteFinishHint[param1 - 1], 64, "MacheteEnableVoteFinishHint");
                }
                else {
                    FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_machete_enable 0");
                    FormatEx(g_szVoteTitle[param1 - 1], 64, "MacheteDisableVoteTitle");
                    FormatEx(g_szVoteHint[param1 - 1], 256, "MacheteDisableVoteHint");
                    FormatEx(g_szVoteFinishHint[param1 - 1], 64, "MacheteDisableVoteFinishHint");
                }
                g_hConfirmMenu.Display(param1, 20);
                g_hConfirmLast[param1 -1] = menu;
            }
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        if (StrEqual(buffer, "TopMenuItemInfStamina")) {
            if (sm_inf_stamina.IntValue <= 0) {
                FormatEx(buffer, 64, "TopMenuItemInfStaminaEnable");
            }
            else {
                FormatEx(buffer, 64, "TopMenuItemInfStaminaDisable");
            }
        }
        else if (StrEqual(buffer, "TopMenuItemMachete")) {
            if (sm_machete_enable.IntValue <= 0) {
                FormatEx(buffer, 64, "TopMenuItemMacheteEnable");
            }
            else {
                FormatEx(buffer, 64, "TopMenuItemMacheteDisable");
            }
        }
        FormatEx(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    return 0;
}

int ModeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        FormatEx(buffer, 64, "%T", "ModeMenuTitle", param1);
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_Select) {
        FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_gamemode %d", param2);
        switch (param2) {
            case 0: {
                FormatEx(g_szVoteTitle[param1 - 1], 64, "DefModeVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "DefModeVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "DefModeVoteFinishHint");
            }
            case 1: {
                FormatEx(g_szVoteTitle[param1 - 1], 64, "RunnerModeVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "RunnerModeVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "RunnerModeVoteFinishHint");
            }
            case 2: {
                FormatEx(g_szVoteTitle[param1 - 1], 64, "KidModeVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "KidModeVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "KidModeVoteFinishHint");
            }
        }
        g_hConfirmMenu.Display(param1, 20);
        g_hConfirmLast[param1 -1] = menu;
        
    }
    else if (action == MenuAction_DrawItem) {
        if (g_GameMode == view_as<GameMode>(param2)) {
            return ITEMDRAW_DISABLED;
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        Format(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack) {
            g_hTopMenu.Display(param1, 20);
        }
    }
    return 0;
}

int DifMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        FormatEx(buffer, 64, "%T", "DifMenuTitle", param1);
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_Select) {
        switch (param2) {
            case 0: {
                FormatEx(g_szVoteCommand[param1 - 1], 128, "sv_difficulty classic;sm_cvar sv_spawn_density %f", sv_spawn_density.FloatValue);
                FormatEx(g_szVoteTitle[param1 - 1], 64, "ClassicDifVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "ClassicDifVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "ClassicDifVoteFinishHint");
                
            }
            case 1: {
                FormatEx(g_szVoteCommand[param1 - 1], 128, "sv_difficulty casual;sm_cvar sv_spawn_density %f", sv_spawn_density.FloatValue);
                FormatEx(g_szVoteTitle[param1 - 1], 64, "CasualDifVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "CasualDifVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "CasualDifVoteFinishHint");
            }
            case 2: {
                FormatEx(g_szVoteCommand[param1 - 1], 128, "sv_difficulty nightmare;sm_cvar sv_spawn_density %f", sv_spawn_density.FloatValue);
                FormatEx(g_szVoteTitle[param1 - 1], 64, "NightmareDifVoteTitle");
                FormatEx(g_szVoteHint[param1 - 1], 256, "NightmareDifVoteHint");
                FormatEx(g_szVoteFinishHint[param1 - 1], 64, "NightmareDifVoteFinishHint");
            }
        }
        g_hConfirmMenu.Display(param1, 20);
        g_hConfirmLast[param1 -1] = menu;
    }
    else if (action == MenuAction_DrawItem) {
        if (g_GameDif == view_as<GameDif>(param2)) {
            return ITEMDRAW_DISABLED;
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        Format(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack) {
            g_hTopMenu.Display(param1, 20);
        }
    }
    return 0;
}

int DensityMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        FormatEx(buffer, 64, "%T", "DensityMenuTitle", param1);
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_Select) {
        float density = 1.0;
        switch (param2) {
            case 0: {
                density = 1.0;
            }
            case 1: {
                density = 1.5;
            }
            case 2: {
                density = 3.0;
            }
            case 3: {
                density = 5.0;
            }
            case 4: {
                g_bListenClient[param1] = true;
                CPrintToChat(param1, 0, "{red}%t {white}%t", "ChatFlag", "DensityCustomHint");
                return 0;
            }
        }
        FormatEx(g_szVoteCommand[param1 - 1], 128, "sm_cvar sv_spawn_density %f", density);
        FormatEx(g_szVoteTitle[param1 - 1], 64, "DensityVoteTitle");
        FormatEx(g_szVoteHint[param1 - 1], 256, "DensityVoteHint");
        FormatEx(g_szVoteFinishHint[param1 - 1], 64, "DensityVoteFinishHint");

        g_fDensity[param1 - 1] = density;

        g_hConfirmLast[param1 -1] = menu;
        g_hConfirmMenu.Display(param1, 20);
    }
    else if (action == MenuAction_DrawItem) {
        if (g_GameDensity == view_as<GameDensity>(param2) && g_GameDensity != GameDensityCustom) {
            return ITEMDRAW_DISABLED;
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        if (StrEqual(buffer, "DensityMenuItemCustom")) {
            char display[64];
            Format(display, 64, "%T", buffer, param1);
            return RedrawMenuItem(display);
        }
        return 0;
    }
    else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack) {
            g_hTopMenu.Display(param1, 20);
        }
    }
    return 0;
}

public Action DensityListener(int client, const char[] command, int argc) {
    if (g_bListenClient[client]) {
        g_bListenClient[client] = false;

        char buffer[64];
        GetCmdArgString(buffer, 64);
        ReplaceString(buffer, 64, "\"", "");
        float density = StringToFloat(buffer);

        //PrintToServer("Listen: %s, %f", buffer, density);

        // if (density < 1.5 || density > 9999999) {
        if (density > 9999999) {
            g_hDensityMenu.Display(client, 20);
        }
        else {
            FormatEx(g_szVoteCommand[client - 1], 128, "sm_cvar sv_spawn_density %f", density);
            FormatEx(g_szVoteTitle[client - 1], 64, "DensityVoteTitle");
            FormatEx(g_szVoteHint[client - 1], 256, "DensityVoteHint");
            FormatEx(g_szVoteFinishHint[client - 1], 64, "DensityVoteFinishHint");

            g_fDensity[client - 1] = density;
            g_hConfirmLast[client -1] = g_hDensityMenu;
            g_hConfirmMenu.Display(client, 20);
        }
        return Plugin_Handled;
    }
    else {
        return Plugin_Continue;
    }
}

int ConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];
        if (StrEqual(g_szVoteTitle[param1 - 1], "DensityVoteTitle")) {
            FormatEx(buffer, 64, "%T%T", "Confirm", param1, g_szVoteTitle[param1 - 1], param1, g_fDensity[param1 - 1]);
        }
        else {
            FormatEx(buffer, 64, "%T%T", "Confirm", param1, g_szVoteTitle[param1 - 1], param1);
        }
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_Select) {
        switch (param2) {
            case 0: {
                DoVote(param1);
            }
            case 1: {
                g_hConfirmLast[param1 - 1].Display(param1, 20);
            }
        }
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        Format(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack) {
            g_hConfirmLast[param1 - 1].Display(param1, 20);
        }
    }
    return 0;
}

void DoVote(int client) {
    if (IsVoteInProgress()) {
        CPrintToChat(client, 0, "{red}%t %t", "ChatFlag", "VoteInProgress");
        g_hConfirmLast[client - 1].Display(client, 20);
    }
    if (IsClientInGame(client)) {
        if (IsPlayerAlive(client)) {
            g_iVoteClient = client;
            g_hVoteMenu.SetTitle(g_szVoteTitle[client - 1]);
            g_hVoteMenu.DisplayVoteToAll(20);

            char buffer[256];
            FetchColoredName(client, buffer, 256);
            if (StrEqual(g_szVoteHint[g_iVoteClient - 1], "DensityVoteHint")) {
                CPrintToChatAll(0, "{green}%t {white}%t", "ChatFlag", g_szVoteHint[client - 1], buffer, g_fDensity[client - 1]);
            }
            else {
                CPrintToChatAll(0, "{green}%t {white}%t", "ChatFlag", g_szVoteHint[client - 1], buffer);
            }
        }
        else {
            CPrintToChat(client, 0, "{red}%t %t", "ChatFlag", "VoteByAlive");
            g_hConfirmLast[client - 1].Display(client, 20);
        }
    }
}

int VoteMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Display) {
        char buffer[64];

        if (StrEqual(g_szVoteTitle[g_iVoteClient - 1], "DensityVoteTitle")) {
            FormatEx(buffer, 64, "%T", "DensityVoteTitle", param1, g_fDensity[g_iVoteClient - 1]);
        }
        else {
            FormatEx(buffer, 64, "%T", g_szVoteTitle[g_iVoteClient - 1], param1);
        }
    
        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(buffer);
    }
    else if (action == MenuAction_VoteEnd) {
        if (param1 == 0) {
            int iWinningVotes, iTotalVotes;
            GetMenuVoteInfo(param2, iWinningVotes, iTotalVotes);

            if (FloatCompare(float(iWinningVotes) / float(iTotalVotes), VOTE_NEEDED) == 1) {
                ServerCommand(g_szVoteCommand[g_iVoteClient - 1]);

                if (StrEqual(g_szVoteFinishHint[g_iVoteClient - 1], "DensityVoteFinishHint")) {
                    CPrintToChatAll(0, "{green}%t {white}%t", "ChatFlag", g_szVoteFinishHint[g_iVoteClient - 1], g_fDensity[g_iVoteClient - 1]);
                }
                else {
                    CPrintToChatAll(0, "{green}%t {white}%t", "ChatFlag", g_szVoteFinishHint[g_iVoteClient - 1]);
                }
                return 0;
            }
        }
        CPrintToChatAll(0, "{red}%t %t", "ChatFlag", "VoteFailed");
    }
    else if (action == MenuAction_VoteCancel) {
        CPrintToChatAll(0, "{red}%t %t", "ChatFlag", "NoVotesCast");
    }
    else if (action == MenuAction_DisplayItem) {
        char buffer[64], display[64];
        menu.GetItem(param2, buffer, 64, _, _, _, param1);
        Format(display, 64, "%T", buffer, param1);
        return RedrawMenuItem(display);
    }
    return 0;
}

// bool IsValidClient(int client)
// {
// 	return 0 < client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && !IsClientSourceTV(client);
// }

public Action GameInfoShowToClient(int client, int args)
{
    bool temp1 = false, temp2 = false, temp3 = false;
    if (sm_inf_stamina != null) {
        if (sm_inf_stamina.IntValue >= 1) {
            temp1 = true;
        }
    }
    if (sm_machete_enable != null) {
        if (sm_machete_enable.IntValue >= 1) {
            temp2 = true;
        }
    }
    if (sm_record_enable_rt != null) {
        temp3 = sm_record_enable_rt.BoolValue;
    }
    if (client == 0) {
        CPrintToChatAll(0, "{green}%t {white}%t {green}%t {white}%t\n{green}%t {white}%.1f {green}%t {white}%t\n{green}%t {white}%t\n{mediumvioletred}%t %t",
            "ModeFlag",            szGameMode[view_as<int>(g_GameMode)],
            "DifFlag",            szGameDif[view_as<int>(g_GameDif)],
            "DensityFlag",        sv_spawn_density.FloatValue,
            "InfStaminaFlag",     temp1 ? "On" : "Off", 
            "MacheteFlag",        temp2 ? "On" : "Off",
            "ChatFlag",           temp3 ? "RecordEnable" : "RecordDisable");
    }
    else {
        CPrintToChat(client, 0, "{green}%t {white}%t {green}%t {white}%t\n{green}%t {white}%.1f {green}%t {white}%t\n{green}%t {white}%t\n{mediumvioletred}%t %t",
            "ModeFlag",            szGameMode[view_as<int>(g_GameMode)],
            "DifFlag",            szGameDif[view_as<int>(g_GameDif)],
            "DensityFlag",        sv_spawn_density.FloatValue,
            "InfStaminaFlag",     temp1 ? "On" : "Off", 
            "MacheteFlag",        temp2 ? "On" : "Off",
            "ChatFlag",           temp3 ? "RecordEnable" : "RecordDisable");
    }
    return Plugin_Handled;
}
