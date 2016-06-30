%%----------------------------------------------------
%% GM命令配置
%% @author yeahoo2000@gmail.com
%% @end
%%----------------------------------------------------
-module(gm_cmd).
-export([
        do/2
        ,cmds/0
        ,save/0
    ]
).

-include("common.hrl").
-include("gm.hrl").
-include("role.hrl").
-include("assets.hrl").
-include("package.hrl").
-include("gain.hrl").
-include("trigger.hrl").
-include("attr.hrl").
-include("link.hrl").
-include("item.hrl").
-include("pos.hrl").
-include("map.hrl").
-include("query.hrl").
-include("battle.hrl").
-include("combat.hrl").
-include("skill.hrl").
-include("wing.hrl").
-include("skill_prac.hrl").
-include("guild.hrl").
-include("plot.hrl").
-include("var.hrl").
-include("trial.hrl").
-include("quest.hrl").
-include("guard.hrl").
-include("treasure.hrl").
-include("pet.hrl").
-include("team.hrl").
-include("notice.hrl").
-include("wedding.hrl").
-include("campaign.hrl").
-include("limit_return.hrl").
-include("friend.hrl").
-include("buff.hrl").
-include("arena.hrl").
-include("camp_dragon_boat.hrl").

-ifdef(enable_gm_cmd).

%% @doc 导出GM命令到文件
-spec save() -> ok.
save() ->
    Content = help(cmds()),
    File = "./gm_cmd.txt",
    case file:write_file(File, Content) of
        ok -> ?P("> 已生成GM命令文件: ~ts~n", [File]);
        Err1 -> ?P("> 生成文件[~ts]时发生异常: ~w~n", [File, Err1])
    end.

%% @doc 命令定义
-spec cmds() -> [#gm_cmd{}].
cmds() ->
    [
        #gm_cmd{
            cmd = "help"
            ,args = [
                {string, "GM命令关键词, 不填为所有", ""}
            ]
            ,desc = "显示相关GM命令帮助信息"
            ,do = fun([Keyword], _Role) ->
                    Cmds = [Cmd || Cmd = #gm_cmd{cmd = Desc} <- cmds(), re:run(unicode:characters_to_binary(Desc), unicode:characters_to_binary(Keyword), [{capture, none}, caseless]) =:= match],
                    {reply, help(Cmds)}
            end
        }
        ,#gm_cmd{
            cmd = "goto"
            ,args = [
                {int, "地图ID", 10001}
                ,{int, "x坐标", 0}
                ,{int, "y坐标", 0}
            ]
            ,desc = "将当前角色传送到指定地点"
            ,do = fun([MapId, X, Y], Role) ->
                    case role_misc:check_event(Role) of
                        {false, Reason} -> {false, Reason};
                        true ->
                            {ToX, ToY} = case map_data:get(MapId) of
                                {ok, #map_data{revive = [{X0, Y0}]}} when X =:= 0 andalso Y =:= 0 -> {X0, Y0};
                                _ -> {X, Y}
                            end,
                            case map:role_enter({MapId, ToX, ToY}, Role) of
                                {error, Reason} -> {reply, Reason};
                                {ok, NewRole} -> {ok, NewRole}
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "获取物品"
            ,args = [
                {int, "BaseId"}
                ,{int, "Num", 1}
                ,{int, "bind", 0}
            ]
            ,desc = "获取一个物品"
            ,do = fun([BaseId, Num, Bind], Role) ->
                    GL = format:val_to_gain([{BaseId, Bind, Num}]),
                    case role_gain:do(GL, Role) of
                        {false, G} -> {reply, G#gain.msg};
                        {ok, NewRole} ->
                            {ok, NewRole}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "清空BUFF"
            ,args = [
            ]
            ,desc = "清空角色全部buff"
            ,do = fun([], Role) ->
                    case buff:gm_clean(Role) of
                        {ok, NewRole} -> {ok, NewRole};
                        {false, Reason} -> {reply, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "清空排行榜"
            ,args = [
            ]
            ,desc = "清空相关排行榜数据"
            ,do = fun([], _Role) ->
                    rank_mgr:cast({clear, all}),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "更新排行榜"
            ,args = [
            ]
            ,desc = "更新排行榜数据"
            ,do = fun([], _Role) ->
                    arena_mgr ! zero_update_rank,
                    rank_mgr ! gm_update_hour_zero,
                    friend_zone ! update_rank,
                    camp_dragon_boat ! update_rank,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "上线时间后退"
            ,args = [
                {int, "小时", 1}
            ]
            ,desc = "上线时间后退"
            ,do = fun([Int], _Role = #role{id = Id}) ->
                    case friend:fetch(by_id, Id) of
                        Data = #friend_role{online_time = OnlineTime} ->
                            _D = max(0, OnlineTime - Int * 3600),
                            friend:update(friend_role, Data#friend_role{online_time = max(0, OnlineTime - Int * 3600)}),
                            ok;
                        _ ->
                            ok
                    end
            end
        }
        ,#gm_cmd{
            cmd = "设世界等级"
            ,args = [
                {int, "档次", 1}
            ]
            ,desc = "设置世界等级档次"
            ,do = fun([Val], _Role) ->
                    world_lev:gm_set(Val),
                    ok
            end
        }

        ,#gm_cmd{
            cmd = "0点更新"
            ,args = []
            ,desc = "进入一次0点更新"
            ,do = fun([], Role = #role{m_var = MVar, m_campaign = MCamp = #m_campaign{acc = AccL, can_reward = CanRewardL, rewarded = Rewarded}, m_limit_return = MLimitReturn = #m_limit_return{login_time = TLoginTime, check_time = TCheckTime, pay_time = TPaytime, end_time = TEndTime} }) ->
                    NewMCamp = MCamp#m_campaign{
                        acc = [{Id, Time - 86400, Info} || {Id, Time, Info} <- AccL]
                        ,can_reward = [{Id, Time - 86400, Info} || {Id, Time, Info} <- CanRewardL]
                        ,rewarded = [{Id, Time - 86400, Info} || {Id, Time, Info} <- Rewarded]
                    },
                    NewMLimitReturn = MLimitReturn#m_limit_return{login_time = max(0, TLoginTime - 86400), check_time = max(0, TCheckTime - 86400), pay_time = max(0, TPaytime - 86400), end_time = max(TEndTime - 86400, 0)},
                    NRole = Role#role{m_var = MVar#m_var{last_reset_time = 0}, m_campaign = NewMCamp, m_limit_return = NewMLimitReturn},
                    var ! update_hour_zero,
                    dungeon_mgr ! update_hour_zero,
                    var:reset(NRole, zero)
            end
        }
        ,#gm_cmd{
            cmd = "限时返利"
            ,args = [
                {int, "后退天数", 1}
            ]
            ,desc = "限时返利，后退天数"
            ,do = fun([Int], Role = #role{m_limit_return = MLimitReturn = #m_limit_return{login_time = TLoginTime, check_time = TCheckTime, pay_time = TPaytime, end_time = TEndTime, start_time = StartTime}, m_var = MVar}) ->
                    NewMLimitReturn = MLimitReturn#m_limit_return{login_time = max(0, TLoginTime - Int * 86400), check_time = max(0, TCheckTime - Int * 86400), pay_time = max(0, TPaytime - Int * 86400), end_time = max(TEndTime - Int * 86400, 0), start_time = max(StartTime - Int * 86400, 0)},
                    NRole = Role#role{ m_limit_return = NewMLimitReturn, m_var = MVar#m_var{last_reset_time = 0}},
                    %% var ! update_hour_zero,
                    var:reset(NRole, zero)
            end
        }
        ,#gm_cmd{
            cmd = "限时返利星期"
            ,args = [
                {int, "开始星期几", 1}
                ,{int, "结束星期几", 7}
            ]
            ,desc = "限时返利星期"
            ,do = fun([Min, Max], Role = #role{m_limit_return = MLimitReturn = #m_limit_return{check_time = TCheckTime}, m_var = MVar}) ->
                    NMin = min(7, Min),
                    NMax = min(7, Max),
                    CheckTimeList = lists:seq(NMin, NMax),
                    NewMLimitReturn = MLimitReturn#m_limit_return{ check_time = max(0, TCheckTime - 86400), check_time_list = CheckTimeList},
                    NRole = Role#role{ m_limit_return = NewMLimitReturn, m_var = MVar#m_var{last_reset_time = 0}},
                    %% var ! update_hour_zero,
                    var:reset(NRole, zero)
            end
        }
        ,#gm_cmd{
            cmd = "5点更新"
            ,args = []
            ,desc = "进入一次5点更新"
            ,do = fun([], Role = #role{m_var = MVar}) ->
                    var ! update_hour_five,
                    var:reset_five(Role#role{m_var = MVar#m_var{last_reset_five_time = 0}}, five)
            end
        }
        ,#gm_cmd{
            cmd = "设开服时间"
            ,args = [
                {int, "年", 2015}
                ,{int, "月", 1}
                ,{int, "日", 1}
                ,{int, "时", 0}
                ,{int, "分", 0}
                ,{int, "秒", 0}
            ]
            ,desc = "修改开服时间"
            ,do = fun([Year, Month, Day, HH, MM, SS], _Role) ->
                    Time = date:datetime_to_seconds({{Year, Month, Day}, {HH, MM, SS}}),
                    env:save(srv_open_time, Time),
                    env ! reset_cache_time,
                    ok
            end
        }
        ,#gm_cmd{
             cmd = "预合服"
             ,args = [
                {string, "邮件内容", ""}
             ]
             ,desc = "预合服"
             ,do = fun([Msg], _Role) ->
                     merge_gift:pre(Msg),
                     ok
             end
         }
        ,#gm_cmd{
             cmd = "查看预合服"
             ,args = [
             ]
             ,desc = "查看预合服"
             ,do = fun([], _Role) ->
                     {ok, {Time, Msg}} = merge_gift:get_pre(),
                     {reply, util:flist("设置时间：~w；设置内容：~ts", [date:seconds_to_datetime(Time), Msg])}
             end
         }
        ,#gm_cmd{
             cmd = "查看合服时间"
             ,args = []
             ,desc = "查看当前服务器合服时间"
             ,do = fun([], _Role) ->
                     {reply, util:flist("~w", [date:seconds_to_datetime(env:get(merge_time))])}
             end
         }
         ,#gm_cmd{
             cmd = "设合服时间"
             ,args = [
                 {int, "年", 2015}
                 ,{int, "月", 1}
                 ,{int, "日", 1}
                 ,{int, "时", 0}
                 ,{int, "分", 0}
                 ,{int, "秒", 0}
             ]
             ,desc = "设合服时间"
             ,do = fun([Year, Month, Day, HH, MM, SS], _Role) ->
                     Time = date:datetime_to_seconds({{Year, Month, Day}, {HH, MM, SS}}),
                     env:save(merge_time, Time),
                     env ! reset_cache_time,
                     ok
             end
         }
        
        ,#gm_cmd{
            cmd = "开机器人"
            ,args = [
                {int, "开始编号", 1}
                ,{int, "结束编号", 1}
                ,{atom, "模式", robot}
                ,{atom, "服", self}
            ]
            ,desc = "模式"
            ,do = fun([Min, Max, _Mod, _Srv], _Role) when Min > Max orelse Max - Min > 2000 ->
                    {reply, "非法参数"};
                ([Min, Max, Mod, Srv], _Role) ->
                    test:t(Srv, Mod, Min, Max),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "关闭机器人"
            ,args = []
            ,desc = "关闭机器人"
            ,do = fun([], _Role) ->
                    tester:info(all, del),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "查看开服时间"
            ,args = []
            ,desc = "查看当前服务器开服时间"
            ,do = fun([], _Role) ->
                    {reply, util:flist("~w", [date:seconds_to_datetime(env:srv_open_time())])}
            end
        }
        ,#gm_cmd{
            cmd = "设储存经验"
            ,args = [
                {int, "经验", 10}
            ]
            ,desc = "设储存经验"
            ,do = fun([Val], Role = #role{assets = Assets}) ->
                    NRole = Role#role{assets = Assets#assets{reserve_exp = Val}},
                    role_gain:push_exp(NRole),
                    {ok, NRole}
            end
        }

        ,#gm_cmd{
            cmd = "设宠物技能"
            ,args = [
                {string, "技能列表", []}
            ]
            ,desc = "设置宠物技能"
            ,do = fun([SkillIds], Role) ->
                    case util:string_to_term(SkillIds) of
                        {error, Err} ->
                            {reply, util:flist("命令的参数格式不正确: ~w", [Err])};
                        {ok, Data} ->
                            ?DEBUG("Data:~w", [Data]),
                            case pet_skill:gm_study(Data, Role) of
                                {ok, NewRole} -> {ok, NewRole};
                                {false, Reason} -> {reply, Reason}
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "设宠物寿命"
            ,args = [
                {int, "寿命", 80}
            ]
            ,desc = "设置宠物寿命"
            ,do = fun([Val], Role = #role{m_pet = Mpet = #m_pet{pets = Pets}}) ->
                    case lists:keyfind(?pet_status_war, #pet.status, Pets) of
                        Pet = #pet{id = PetId} ->
                            Pet1 = Pet#pet{happy = Val},
                            NewPets = lists:keystore(PetId, #pet.id, Pets, Pet1),
                            Role1 = Role#role{m_pet = Mpet#m_pet{pets = NewPets}},
                            pet:push_10502(Role1, Pet1),
                            {ok, Role1};
                        _ ->
                            {reply, ?T("没有找到出战宠物")}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "守护测试包"
            ,args = []
            ,desc = "获取守护测试包"
            ,do = fun([], Role) ->
                    GL = format:val_to_gain([{90000, 0, 1000000}
                                             , {90001, 0, 1000000}
                                             , {90002, 0, 1000000}
                                             , {90003, 0, 1000000}
                                            ]),
                    case role_gain:do(GL, Role) of
                        {false, G} -> {reply, G#gain.msg};
                        {ok, NewRole} ->
                            {ok, NewRole}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "清空守护"
            ,args = []
            ,desc = "清空守护数据"
            ,do = fun([], Role) ->
                    {ok, Role#role{m_guard = #m_guard{}}}
            end
        }
        ,#gm_cmd{
            cmd = "清空邮件"
            ,args = []
            ,desc = "清空邮件"
            ,do = fun([], Role) ->
                    {ok, Role#role{m_mail = []}}
            end
        }
        ,#gm_cmd{
            cmd = "清空藏宝图"
            ,args = []
            ,desc = "清空藏宝图"
            ,do = fun([], Role = #role{m_quest = Mquest}) ->
                    {ok, Role#role{m_quest = Mquest#m_quest{quest_treasure = #quest_treasure{}}}}
            end
        }
        ,#gm_cmd{
            cmd = "终止战斗"
            ,args = []
            ,desc = "终止当前战斗"
            ,do = fun([], #role{m_combat = #m_combat{pid = CombatPid}}) ->
                    case is_pid(CombatPid) of
                        true -> CombatPid ! stop;
                        false -> ignore
                    end,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "战斗站位"
            ,args = []
            ,desc = "打印当前战斗站位"
            ,do = fun([], #role{m_combat = #m_combat{pid = CombatPid}}) ->
                    case is_pid(CombatPid) of
                        true -> CombatPid ! print_pos;
                        false -> ignore
                    end,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "终止战斗结算"
            ,args = []
            ,desc = "终止当前战斗"
            ,do = fun([], #role{m_combat = #m_combat{pid = CombatPid}}) ->
                    case is_pid(CombatPid) of
                        true -> CombatPid ! stop_result;
                        false -> ignore
                    end,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "变神器"
            ,args = []
            ,desc = "隐藏命令"
            ,do = fun([], Role = #role{p_eqm = Peqm = #package{items = Items}}) ->
                    case lists:keyfind(1, #item.id, Items) of
                        false ->
                            ok;
                        Item ->
                            Attr = [#attr_base{type = ?attr_type_special, name = ?attr_phy_dmg, calc_type = ?attr_calc_val, val = 9999999}, #attr_base{type = ?attr_type_special, name = ?attr_magic_dmg, calc_type = ?attr_calc_val, val = 9999999}, #attr_base{type = ?attr_type_special, name = ?attr_atk_speed, calc_type = ?attr_calc_val, val = 99999}, #attr_base{type = ?attr_type_special, name = ?attr_phy_def, calc_type = ?attr_calc_val, val = 99999}, #attr_base{type = ?attr_type_special, name = ?attr_magic_def, calc_type = ?attr_calc_val, val = 99999}],
                            NewItem = Item#item{attr = Attr},
                            NewItems = lists:keystore(1, #item.id, Items, NewItem),
                            NewPeqm = Peqm#package{items = NewItems},
                            Role1 = Role#role{p_eqm = NewPeqm},
                            Role2 = attr:calc_and_push(Role1),
                            {ok, Role2}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "变速度"
            ,args = [
                {int, "出手速度", 0}
            ]
            ,desc = "隐藏命令"
            ,do = fun([Val], Role = #role{p_eqm = Peqm = #package{items = Items}}) ->
                    case lists:keyfind(1, #item.id, Items) of
                        false ->
                            ok;
                        Item ->
                            Attr = [#attr_base{type = ?attr_type_special, name = ?attr_atk_speed, calc_type = ?attr_calc_val, val = Val}],
                            NewItem = Item#item{attr = Attr},
                            NewItems = lists:keystore(1, #item.id, Items, NewItem),
                            NewPeqm = Peqm#package{items = NewItems},
                            Role1 = Role#role{p_eqm = NewPeqm},
                            Role2 = attr:calc_and_push(Role1),
                            {ok, Role2}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "清空宝图"
            ,args = []
            ,desc = "清空宝图"
            ,do = fun([], Role) ->
                    Role1 = Role#role{m_treasure = #m_treasure{}},
                    treasure:push_13600(Role1),
                    {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "禁言"
            ,args = [
                {int, "玩家id", 0}
                ,{int, "时间", 0}
                ,{string, "隐藏信息", "GM命令"}
                ,{string, "信息", "GM命令"}
            ]
            ,desc = "禁言"
            ,do = fun([Id, Time, Hide, Msg], _Role = #role{id = {RoleId, _, _}, name = Name}) ->
                    case Id == 0 orelse Id == RoleId of
                        true -> {reply, "输入角色id，不是是自己哦"};
                        _ ->
                            Platform = env:get(platform),
                            ZoneId = env:get(zone_id),
                            NewId = case Id == 0 of
                                true -> RoleId;
                                _ -> Id
                            end,
                            adm:silent([{NewId, Platform, ZoneId}], Time, Hide, Msg, Name),
                            ok
                    end
            end
        }
        ,#gm_cmd{
            cmd = "封号"
            ,args = [
                {int, "玩家id", 0}
                ,{int, "时间", 0}
                ,{string, "信息", "GM命令"}
            ]
            ,desc = "封号"
            ,do = fun([Id, Time,  Msg], _Role = #role{id = {RoleId, _, _}, name = Name}) ->
                    case Id == 0 orelse Id == RoleId of
                        true -> {reply, "输入角色id，不是是自己哦"};
                        _ ->
                            Platform = env:get(platform),
                            ZoneId = env:get(zone_id),
                            NewId = case Id == 0 of
                                true -> RoleId;
                                _ -> Id
                            end,
                            adm:lock([{NewId, Platform, ZoneId}], Time,  Msg, Name),
                            ok
                    end
            end
        }
        ,#gm_cmd{
            cmd = "解禁"
            ,args = [
                {int, "玩家id", 0}
            ]
            ,desc = "解禁"
            ,do = fun([Id], _Role = #role{id = {RoleId, _, _}, name = Name}) ->
                    case Id == 0 orelse Id == RoleId of
                        true -> {reply, "输入角色id，不是是自己哦"};
                        _ ->
                            Platform = env:get(platform),
                            ZoneId = env:get(zone_id),
                            NewId = case Id == 0 of
                                true -> RoleId;
                                _ -> Id
                            end,
                            adm:unlock([{NewId, Platform, ZoneId}], Name),
                            ok
                    end
            end
        }
        ,#gm_cmd{
            cmd = "弹幕"
            ,args = [
            ]
            ,desc = "弹幕"
            ,do = fun([], #role{name = Name}) ->
                    notice:cast(all, ?notice_barrage, notice:format(?T("~ts 来一波弹幕"), [{role_2, Name}])),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "完成师徒日常"
            ,args = [
            ]
            ,desc = "完成师徒日常"
            ,do = fun([], Role) ->
                    {ok, NewRole} = teacher:gm(Role, finish_daily),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "清空师徒"
            ,args = [
            ]
            ,desc = "清空师徒"
            ,do = fun([], Role) ->
                    NewRole = Role#role{m_teacher = teacher:init()},
                    teacher:push(NewRole),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "师徒日常后退"
            ,args = [
            ]
            ,desc = "师徒日常后退"
            ,do = fun([], Role) ->
                    {ok, NewRole} = teacher:gm(Role, daily_before),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "徒弟贡献"
            ,args = [
                {int, "贡献良师值", 0}
            ]
            ,desc = "徒弟贡献"
            ,do = fun([Int], Role) ->
                    {ok, NewRole} = teacher:gm(Role, {student_score, Int}),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "lookup"
            ,args = [
                {string, "字段名", "m_skill"}
                ,{int, "二级字段位置(0为所有)", 0}
            ]
            ,desc = "查看角色数据"
            ,do = fun([Filed, Pos], Role) ->
                    F = list_to_atom(Filed),
                    L = ?record_to_tuplelist(role, Role),
                    case lists:keyfind(F, 1, L) of
                        {_, Val} when Pos =:= 0 -> {reply, util:flist("~ts ==> ~w", [Filed, Val])};
                        {_, Val} -> {reply, util:flist("~ts ==> ~w", [Filed, element(Pos, Val)])};
                        _ -> {reply, "查找不到内容"}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "加经验"
            ,args = [
                {int, "值", 0}
            ]
            ,desc = "增加角色经验"
            ,do = fun([Val], Role) ->
                    case role_gain:do_notice([#gain{label = exp, val = Val}], Role) of
                        {false, G} -> {reply, G#gain.msg};
                        {ok, NewRole} ->
                            {ok, NewRole}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "设职业"
            ,args = [
                {int, "值", 1}
            ]
            ,desc = "设置当前角色的职业[]"
            ,do = fun([Val], Role = #role{pid = Pid, p_eqm = Peqm = #package{items = Items}}) ->
                    case Val >= 1 andalso Val =< 5 of
                        true ->
                            Role1 = Role#role{p_eqm = Peqm#package{items = []}},
                            package:push_item_info(del, Role1, [{?package_type_eqm, Items}]),
                            NRole = attr:calc_and_push(Role1#role{classes = Val}),
                            NewRole = NRole#role{m_skill = #m_skill{skills = []}},
                            {ok, NewRole1 = #role{m_skill = #m_skill{skills = Skills}}} = skill:login(NewRole),
                            role:pack_send(Pid, 10800, {Skills}),
                            attr:push_10000(NewRole1),
                            map:role_update(NewRole1),
                            {ok, NewRole1};
                        false ->
                            {reply, ?T("非法职业")}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "设银币"
            ,args = [
                {int, "值", 1}
            ]
            ,desc = "设置银币"
            ,do = fun([Val], Role = #role{assets = Assets, pid = Pid}) ->
                            NewAssets = Assets#assets{
                                coin = Val
                            },
                            Role1 = Role#role{assets = NewAssets},
                            role:pack_send(Pid, 10002, {NewAssets}),
                            {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "设金币"
            ,args = [
                {int, "值", 1}
            ]
            ,desc = "设置金币"
            ,do = fun([Val], Role = #role{assets = Assets, pid = Pid}) ->
                            NewAssets = Assets#assets{
                                gold_bind = Val
                            },
                            Role1 = Role#role{assets = NewAssets},
                            role:pack_send(Pid, 10002, {NewAssets}),
                            {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "设钻石"
            ,args = [
                {int, "值", 1}
            ]
            ,desc = "设置钻石"
            ,do = fun([Val], Role = #role{assets = Assets, pid = Pid}) ->
                            NewAssets = Assets#assets{
                                gold = Val
                            },
                            Role1 = Role#role{assets = NewAssets},
                            role:pack_send(Pid, 10002, {NewAssets}),
                            {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "加宠物经验"
            ,args = [
                {int, "值", 0}
            ]
            ,desc = "增加宠物经验"
            ,do = fun([Val], Role) ->
                    case role_gain:do([#gain{label = pet_exp, val = Val}], Role) of
                        {false, G} -> {reply, G#gain.msg};
                        {ok, NewRole} ->
                            {ok, NewRole}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "设宠物等级"
            ,args = [
                {int, "值", 0}
            ]
            ,desc = "设置出战宠物等级"
            ,do = fun([Val], Role = #role{m_pet = Mpet = #m_pet{pets = Pets}}) ->
                    case lists:keyfind(?pet_status_war, #pet.status, Pets) of
                        Pet = #pet{id = PetId, pet_attr = PetAttr} ->
                            NewPetAttr= PetAttr#pet_attr{p_str = 2, p_con = 2, p_mag = 2, p_agi = 2, p_end = 2, point = 0},
                            NewPet = Pet#pet{lev = 1, exp = 0, pet_attr = NewPetAttr},
                            NewPets = lists:keystore(PetId, #pet.id, Pets, NewPet),
                            Role1 = Role#role{m_pet = Mpet#m_pet{pets = NewPets}},
                            %% 计算到某一个等级宠物需要的经验
                            Lev = max(1, Val),
                            pet:gm_set_pet_lev(Role1, Lev);
                        _ ->
                            {reply, ?T("没有找到出战宠物")}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "技能"
            ,args = [
                {int, "值", 1}
            ]
            ,desc = "学习角色全部技能"
            ,do = fun([Val], Role = #role{m_skill = MSkill = #m_skill{skills = Skills}}) ->
                    NewSkills = [{SkillId, Val} || {SkillId, _} <- Skills],
                    NewRole = Role#role{m_skill = MSkill#m_skill{skills = NewSkills}},
                    role:link_send(NewRole, 10800, {NewSkills}),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "单个技能"
            ,args = [
                {int, "技能id"}
                ,{int, "等级", 1}
            ]
            ,desc = "学习角色单个技能"
            ,do = fun([SkillId, Lev], Role = #role{m_skill = MSkill = #m_skill{skills = Skills}}) ->
                    case lists:keyfind(SkillId, 1, Skills) of
                        {_, _} ->
                            NewSkills = lists:keystore(SkillId, 1, Skills, {SkillId, Lev}),
                            NewRole = Role#role{m_skill = MSkill#m_skill{skills = NewSkills}},
                            role:link_send(NewRole, 10800, {NewSkills}),
                            {ok, NewRole};
                        _ ->
                            {false, "无法学习其他职业的技能"}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "获取宠物"
            ,args = [
                {int, "值", 10001}
                ,{int, "等级", 1}
            ]
            ,desc = "获得一只宠物"
            ,do = fun([Val, Lev], Role) ->
                    case pet:create(Role, #{base_id => Val, lev => Lev, from => "GM"}) of
                        {ok, NewRole} ->
                            {ok, NewRole};
                        {false, Reason} ->
                            {false, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "清空宠物"
            ,args = [
            ]
            ,desc = ""
            ,do = fun([], Role = #role{m_pet = Mpet = #m_pet{pets = OldPets}}) ->
                    NewMpet = Mpet#m_pet{pets = [], next_id = 1},
                    NewRole = Role#role{m_pet = NewMpet},
                    lists:foreach(fun(#pet{id = PetId}) ->
                                role:link_send(Role, 10522, {PetId, ?true, ""})
                        end, OldPets),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "清空背包"
            ,args = []
            ,desc = "清空背包"
            ,do = fun([], Role = #role{p_bag = Bag = #package{volume = Volume, type = Type, items = Items}}) ->
                    package:push_item_info(del, Role, [{Type, Items}]),
                    {ok, Role#role{p_bag = Bag#package{items = [], free_cell = ?free_cell(1, Volume)}}}
            end
        }
        ,#gm_cmd{
            cmd = "清空装备"
            ,args = []
            ,desc = "清空装备"
            ,do = fun([], Role = #role{p_eqm = Eqm = #package{items = Items}}) ->
                    package:push_item_info(del, Role, [{?package_type_eqm, Items}]),
                    {ok, Role#role{p_eqm = Eqm#package{items = []}}}
            end
        }
       ,#gm_cmd{
            cmd = "获取野生宠物"
            ,args = [
                {int, "值", 10001}
                ,{int, "数量", 30}
            ]
            ,desc = "获得野生宠物"
            ,do = fun([Val, Num], Role) ->
                    F = fun(_, Role0) ->
                            case pet:create(Role0, #{base_id => Val, genre => 3, from => "GM"}) of
                                {ok, NewRole} ->
                                    NewRole;
                                {false, _} ->
                                    Role0
                            end
                    end,
                    {ok, lists:foldl(F, Role, lists:seq(1, Num))}
            end
        }
        ,#gm_cmd{
            cmd = "设等级"
            ,args = [
                {int, "值", 20}
            ]
            ,desc = "设置当前角色的等级"
            ,do = fun([Val], Role = #role{lev = OldLev, assets = Assets}) ->
                    case Val > 100 orelse Val < 1 of
                        true -> {reply, "参数非法"};
                        false ->
                            Role1 = Role#role{lev = Val, assets = Assets#assets{exp = 0}, is_gain = true},
                            %% 这里先改掉角色加点
                            case Val >= OldLev of
                                true ->
                                    role_gain:push_exp(Role1),
                                    {ok, Role1};
                                false ->
                                    NewRole = attr:calc_and_push(Role1),
                                    role_gain:push_exp(NewRole),
                                    {ok, NewRole}
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "打自己"
            ,args = [
            ]
            ,desc = "打自己（克隆人）"
            ,do = fun(_, Role = #role{}) ->
                    {ok, F1} = role_convert:to(fighter, Role),
                    {ok, F2} = role_convert:to(fighter_clone, Role),
                    combat_mgr:start_combat(?combat_type_unknown, [F1], [F2]),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "击杀NPC"
            ,args = [
                {int, "值"}
            ]
            ,desc = "击杀NPC"
            ,do = fun([Val], Role = #role{}) ->
                    case team:get_fighters(Role) of
                        {ok, AtkList} ->
                            combat_mgr:start_combat(?combat_type_kill_unit, AtkList, [{unit_baseid, Val}]),
                            ok;
                        {false, Reason} -> {reply, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "击杀固定NPC"
            ,args = [
                {int, "值"}
                ,{int, "站位", 1}
            ]
            ,desc = "击杀NPC"
            ,do = fun([Val, Val2], Role = #role{}) ->
                    case team:get_fighters(Role) of
                        {ok, AtkList} ->
                            combat_mgr:start_combat(?combat_type_kill_unit, AtkList, [{unit_baseid, Val, Val2}]),
                            ok;
                        {false, Reason} -> {reply, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "打人"
            ,args = [
                {string, "角色名"}
            ]
            ,desc = "打某人"
            ,do = fun([Name], Role = #role{id = {_, P, Z}}) ->
                    case role_query:local_index(by_name, Name, P, Z) of
                        {ok, #name_index{id = Id}} ->
                            combat_mgr:start_combat(?combat_type_unknown, [Role], [{Id, P, Z}]),
                            ok;
                        _ ->
                            {reply, "查找不到对方"}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "开启roll"
            ,args = [
                {int, "类型,0:普通, 1:副本 2:组队 3:幻境"}
                ,{int, "id"}
            ]
            ,desc = "开启一个roll任务"
            ,do = fun([Mode, Id], Role) ->
                    Result = team:get_status(Role),
                    RoleList = case Result of
                        {true, ?team_mate_leader} ->
                            case team:get_members(Role) of
                                TeamList = [_|_]-> [Role | TeamList];
                                _ -> [Role]
                            end;
                        _ ->
                            [Role]
                    end,
                    case Mode of
                        0 -> roll:normal_roll(Id, RoleList);
                        1 -> roll:dungeon_roll(Id, RoleList);
                        2 -> roll:team_roll(Id, RoleList);
                        3 -> roll:fairyland_box(Id, RoleList);
                        _ ->
                            ok
                    end
            end
        }
        ,#gm_cmd{
            cmd = "不存档"
            ,args = [
            ]
            ,desc = "本次登录所有角色变化状态不存档, 如果备份 则为备份状态"
            ,do = fun([], _Role = #role{s_event = ?event_normal}) ->
                    put(role_bak_flag, true),
                    ok;
                ([], _Role) ->
                    {false, "当前不能进行此操作"}
            end
        }

        ,#gm_cmd{
            cmd = "存档"
            ,args = [
            ]
            ,desc = "登录所有角色变化状态存档, (配合 永久不存档 使用)"
            ,do = fun([], Role = #role{s_event = ?event_normal}) ->
                    {ok, var:del_var(Role, other, role_bak_flag)};
                ([], _Role) ->
                    {false, "当前不能进行此操作"}
            end
        }
        ,#gm_cmd{
            cmd = "永不存档"
            ,args = [
            ]
            ,desc = "以后每次登录所有角色变化状态不存档, 如果备份 则为备份状态 直到<<存档>>命令出现 注意：本操作会备份一次"
            ,do = fun([], Role = #role{s_event = ?event_normal}) ->
                    NRole = var:set_var(Role, other, role_bak_flag, 1),
                    put(role_bak, NRole),
                    {ok, NRole};
                ([], _Role) ->
                    {false, "当前不能进行此操作"}
            end
        }
        ,#gm_cmd{
            cmd = "备份"
            ,args = [
            ]
            ,desc = "登记角色当前状态"
            ,do = fun([], Role = #role{s_event = ?event_normal}) ->
                    put(role_bak, Role),
                    ok;
                ([], _Role) ->
                    {false, "当前不能进行此操作"}
            end
        }
        ,#gm_cmd{
            cmd = "下线"
            ,args = [
            ]
            ,desc = "角色主动下线"
            ,do = fun([], #role{pid = Pid}) when is_pid(Pid) ->
                    role:disconnect(Pid, normal_exit),
                    {reply, "角色下线成功"};
                  ([], _Role) ->
                    {false, "当前不能进行此操作"}
            end
        }
        ,#gm_cmd{
            cmd = "增加公会资金"
            ,args = [
                {int, "值"}
            ]
            ,desc = "增加当前公会的资金"
            ,do = fun([Val], Role = #role{}) ->
                    guild_common:add_assets(Val, Role),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "变身"
            ,args = [
                {string, "类型"}
            ]
            ,desc = "执行GM命令组"
            ,do = fun([Type], Role) ->
                    gm(Type, Role)
            end
        }
        ,#gm_cmd{
            cmd = "退副本"
            ,args = [
            ]
            ,desc = "退出副本"
            ,do =
            fun([], Role) ->
                    case dungeon_util:team_check(exit, Role) of
                        false -> {reply, ?T("您在队伍中, 只有队长和暂离队员才能操作")};
                        {true, Status} ->
                            case dungeon:role_exit(Status, Role) of
                                {false, Reason} ->
                                    {reply, Reason};
                                {ok} -> ok;
                                {ok, NewRole} ->
                                    {ok, NewRole}
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "完成任务链"
            ,args = [
                {int, "尾任务ID"}
            ]
            ,desc = "完成到指定任务链"
            ,do = fun([Id], Role) ->
                    quest:finish_line(Role, Id)
            end
        }
        ,#gm_cmd{
            cmd = "放弃任务"
            ,args = [
                {int, "任务ID"}
            ]
            ,desc = "放弃任务"
            ,do = fun([Id], Role) ->
                    quest:giveup(Id, Role)
            end
        }
        ,#gm_cmd{
            cmd = "清空变量"
            ,args = [
            ]
            ,desc = "清空变量"
            ,do = fun([], Role = #role{m_var = MVar = #m_var{other_vars = OtherVars}}) ->
                    NewOtherVars = [{Key, Val} || {Key, Val} <- OtherVars, Key =:= ?var_other_world_lev],
                    NRole = Role#role{m_var = MVar#m_var{day_vars = [], acc_vars = [], other_vars = NewOtherVars, day_five_vars = [], week_five_vars = []}},
                    {ok, NRole}
            end
        }
        ,#gm_cmd{
            cmd = "加试炼次数"
            ,args = [
            ]
            ,desc = "增加试炼次数"
            ,do = fun([], Role = #role{m_trial = Mtrial}) ->
                    NewMtrial = Mtrial#m_trial{reset = 1},
                    NewRole = Role#role{m_trial = NewMtrial},
                    trial:push_13100(NewRole),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "公会跨天"
            ,args = []
            ,desc = "公会跨天测试"
            ,do = fun([], #role{m_guild = Mg}) ->
                    case Mg of
                        #m_guild{pid = GuildPid} -> GuildPid ! reset;
                        _ -> skip
                    end,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会健康度更新"
            ,args = []
            ,desc = "公会健康度更新"
            ,do = fun([], #role{}) ->
                    lists:foreach(fun([Pid]) ->
                                Pid ! maintain_health
                        end, ets:match(guild_list, #guild{pid = '$1', _='_'})),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "设公会健康度"
            ,args = [
                {int, "健康度"}
            ]
            ,desc = "设置公会健康度"
            ,do = fun([Health], Role) ->
                    guild_union:gm(Role, {set_health, Health}),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会合并"
            ,args = [
            ]
            ,desc = "公会自动合并"
            ,do = fun([], _Role) ->
                    guild_mgr ! auto_merge,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "设入会时间"
            ,args = [
                {int, "秒"}
            ]
            ,desc = "设置时间"
            ,do = fun([Secs], Role = #role{m_guild = MG = #m_guild{pid = Pid}, id = Id}) ->
                    Entered = max(0, date:unixtime() - Secs),
                    Fun = fun(G = #guild{members = Members}) ->
                            NewMembers = case lists:keyfind(Id, #guild_role.id, Members) of
                                R = #guild_role{} -> lists:keyreplace(Id, #guild_role.id, Members, R#guild_role{enter_time = Entered});
                                _ -> Members
                            end,
                            {ok, G#guild{members = NewMembers, flag = ?true}}
                    end,
                    guild_mgr:apply(async, Pid, {Fun}),
                    {ok, Role#role{m_guild = MG#m_guild{enter_time = Entered}}};
                (_, _) ->
                    {false, ?T("不在公会")}
            end
        }
        ,#gm_cmd{
            cmd = "设公会时间"
            ,args = [
                {int, "秒"}
            ]
            ,desc = "设置时间"
            ,do = fun([Secs], _Role = #role{m_guild = #m_guild{pid = Pid}}) ->
                    Fun = fun(G = #guild{}) ->
                            {ok, G#guild{create_time = max(0, date:unixtime() - Secs), flag = ?true}}
                    end,
                    guild_mgr:apply(async, Pid, {Fun}),
                    ok;
                (_, _) ->
                    {false, ?T("不在公会")}
            end
        }
        ,#gm_cmd{
            cmd = "设公会等级"
            ,args = [
                {int, "等级"}
            ]
            ,desc = "设置公会等级"
            ,do = fun([Lev], Role = #role{m_guild = MG = #m_guild{pid = Pid}}) ->
                    Fun = fun(G = #guild{}) ->
                            {ok, G#guild{lev = Lev, flag = ?true}}
                    end,
                    guild_mgr:apply(async, Pid, {Fun}),
                    {ok, Role#role{m_guild = MG#m_guild{guild_lev = Lev}}};
                (_, _) ->
                    {false, ?T("不在公会")}
            end
        }
        ,#gm_cmd{
            cmd = "设公会人数"
            ,args = [
                {int, "人数"}
            ]
            ,desc = "设置公会人数"
            ,do = fun([Num], _Role = #role{m_guild = #m_guild{pid = Pid}}) ->
                    Fun = fun(G = #guild{}) ->
                            {ok, G#guild{mem_num = Num, flag = ?true}}
                    end,
                    guild_mgr:apply(async, Pid, {Fun}),
                    ok;
                (_, _) ->
                    {false, ?T("不在公会")}
            end
        }
        ,#gm_cmd{
            cmd = "公会战"
            ,args = [
            ]
            ,desc = "公会战状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(guild_war, timeout),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会战匹配"
            ,args = [
            ]
            ,desc = "公会战匹配"
            ,do = fun([], _Role) ->
                    guild_war ! match,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会战匹配消息"
            ,args = [
            ]
            ,desc = "公会战匹配消息"
            ,do = fun([], _Role) ->
                    guild_war:gm(match_notice),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会战判定"
            ,args = [
            ]
            ,desc = "公会战进入判定胜负阶段"
            ,do = fun([], _Role) ->
                    guild_war ! judge,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会宝藏"
            ,args = [
            ]
            ,desc = "公会宝藏"
            ,do = fun([], #role{m_guild = #m_guild{id = Gid}}) ->
                    guild_treasure:add(Gid),
                    ok;
                (_, _) ->
                    {false, ?T("还没加入公会")}
            end
        }
        ,#gm_cmd{
            cmd = "公会宝藏跳转"
            ,args = [
            ]
            ,desc = "公会宝藏跳转"
            ,do = fun([], #role{m_guild = #m_guild{pid = Pid}}) ->
                    Pid ! gen_treasure_unit,
                    ok;
                (_, _) ->
                    {false, ?T("还没加入公会")}
            end
        }

        ,#gm_cmd{
            cmd = "加功勋宝箱"
            ,args = [
                {int, "数量"}
            ]
            ,desc = "增加功勋宝箱"
            ,do = fun([Num], #role{m_guild = #m_guild{id = Gid}}) ->
                    guild_loot:add(Gid, [{23014, Num}]),
                    ok;
                (_, _) ->
                    {false, ?T("还没加入公会")}
            end
        }
        ,#gm_cmd{
            cmd = "清功勋宝箱"
            ,args = [
            ]
            ,desc = "清功勋宝箱分配记录"
            ,do = fun(_, #role{m_guild = #m_guild{id = Gid}}) ->
                    guild_loot:gm(Gid, clear),
                    ok;
                (_, _) ->
                    {false, ?T("还没加入公会")}
            end
        }
        ,#gm_cmd{
            cmd = "公会精英战"
            ,args = [
            ]
            ,desc = "公会精英战状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(guild_hero, timeout),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会精英战匹配"
            ,args = [
            ]
            ,desc = "公会精英战状态切换"
            ,do = fun([], _Role) ->
                    guild_hero ! round_match,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会精英战开打"
            ,args = [
            ]
            ,desc = "公会精英战状态切换"
            ,do = fun([], _Role) ->
                    guild_hero ! match_fight,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "公会精英战结算"
            ,args = [
            ]
            ,desc = "公会精英战回合结算"
            ,do = fun([], _Role) ->
                    guild_hero ! round_over,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "获取称号"
            ,args = [
                {int, "称号ID", 0}
            ]
            ,desc = "获取称号"
            ,do = fun([Id], Role) ->
                    EndT = 0,
                    case honor:add_and_use(Role, {Id, EndT}, push) of
                        {ok, NRole} -> {ok, NRole};
                        ok -> {reply, ?T("获取失败")}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "获得任务"
            ,args = [
                     {int, "任务ID", 0}
                    ]
            ,desc = "获得任务"
            ,do = fun([Id], Role = #role{m_quest = MQuest = #m_quest{acceptable = Acceptable}}) ->
                          case quest:force_accept(Id, Role#role{m_quest = MQuest#m_quest{acceptable = [Id | Acceptable]}}) of
                              {ok, NRole} -> {ok, NRole};
                              _ -> {reply, ?T("获得失败，不满足条件")}
                          end
                  end
        }
        ,#gm_cmd{
            cmd = "公告重载"
            ,args = [
            ]
            ,desc = "重载公告数据"
            ,do = fun([], _Role) ->
                    notice_board:reload(),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "商城重载"
            ,args = [
            ]
            ,desc = "商城重载"
            ,do = fun([], _Role) ->
                    shop_mgr:reload(),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "查看任务"
            ,args = [
                     {int
                      , "已接任务:0; 可接任务:1; 已完成任务:2; 悬赏任务:3; 职业任务:4; 主线任务：5; 历练任务(屠魔)：10;"
                      , 0}
                    ]
            ,desc = "查看任务"
            ,do = fun([Type], Role) ->
                      Reply = quest:gm_lookup_quest(Type, Role),
                      {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "清空历练"
            ,args = []
            ,desc = "查看历练（屠魔）任务"
            ,do = fun([], Role) ->
                      Reply = quest_kill:gm_clean(Role),
                      {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "设置职业任务时间"
            ,args = [
            ]
            ,desc = "设置职业任务时间"
            ,do = fun([], Role) ->
                          quest_classes:set_accept_time(Role)
                  end
        }
        ,#gm_cmd{
            cmd = "设置悬赏环数"
            ,args = [{int, "环数", 1}]
            ,desc = "设置悬赏任务环数"
            ,do = fun([Count], Role) ->
                          quest_offer:gm_set_daycount(Count, Role)
                  end
        }
        ,#gm_cmd{
            cmd = "设置悬赏队长环数"
            ,args = [{int, "环数", 1}]
            ,desc = "设置悬赏任务队长环数"
            ,do = fun([Count], Role) ->
                          quest_offer:gm_set_leader_count(Count, Role)
                  end
        }
        ,#gm_cmd{
            cmd = "设置任务链环数"
            ,args = [{int, "环数", 1}]
            ,desc = "设置任务链环数"
            ,do = fun([Round], Role) ->
                          quest_chain:gm_set_round(Round, Role)
                  end
        }
        ,#gm_cmd{
            cmd = "重置任务链"
            ,args = []
            ,desc = "重置任务链"
            ,do = fun([], Role) ->
                          quest_chain:gm_reset(Role)
                  end
        }
        ,#gm_cmd{
            cmd = "护送sss"
            ,args = [
            ]
            ,desc = "直接刷新到sss护送"
            ,do = fun([], Role) ->
                          escort:gm_sss(Role)
                  end
        }
        ,#gm_cmd{
            cmd = "吃货游行"
            ,args = [
            ]
            ,desc = "切换吃货游行的活动状态"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(parade, timeout)
                  end
        }
        ,#gm_cmd{
            cmd = "公会温泉"
            ,args = [
            ]
            ,desc = "切换公会温泉的活动状态"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(guild_spring, timeout)
                  end
        }
        ,#gm_cmd{
            cmd = "公会盗贼"
            ,args = [
            ]
            ,desc = "切换公会盗贼活动状态"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(guild_robber, timeout)
                  end
        }
        ,#gm_cmd{
            cmd = "生成盗贼"
            ,args = [
            ]
            ,desc = "切换生成公会盗贼到公会领地"
            ,do = fun([], _Role) ->
                    guild_robber ! gm_monster,
                    ok
                  end
        }
        ,#gm_cmd{
            cmd = "盗贼宝箱"
            ,args = [
            ]
            ,desc = "生成盗贼宝箱"
            ,do = fun([], Role) ->
                    guild_robber:gm(Role, create_box_switch),
                    ok
                  end
        }
        ,#gm_cmd{
            cmd = "清盗贼宝箱"
            ,args = [
            ]
            ,desc = "清理盗贼宝箱"
            ,do = fun([], Role) ->
                    guild_robber:gm(Role, clear_box),
                    ok
                  end
        }
        ,#gm_cmd{
            cmd = "公会商店提示"
            ,args = [
            ]
            ,desc = "提示一下公会商店更新"
            ,do = fun([], _Role) ->
                    sys_conn:pack_send(11120, {0}),
                    ok
                  end
        }
        ,#gm_cmd{
            cmd = "刷冒险宝箱"
            ,args = [
            ]
            ,desc = "刷新貌相宝箱"
            ,do = fun([], _Role) ->
                    skill_prac_box ! gen_box,
                    ok
                  end
        }
        ,#gm_cmd{
            cmd = "冒险人品模式"
            ,args = [
            ]
            ,desc = "开启冒险宝箱人品模式"
            ,do = fun([], Role) ->
                    skill_prac_box:gm(Role, best_luck)
                  end
        }
        ,#gm_cmd{
            cmd = "冒险普通模式"
            ,args = [
            ]
            ,desc = "开启冒险宝箱普通模式"
            ,do = fun([], Role) ->
                    skill_prac_box:gm(Role, normal_luck)
                  end
        }
        ,#gm_cmd{
            cmd = "冒险技能"
            ,args = [{int, "等级", 1},
                     {int, "经验", 1}
                    ]
            ,desc = "冒险技能"
            ,do = fun([Lev, Exp], Role = #role{m_skill = MSkill = #m_skill{skill_prac = Skills}}) ->
                          NewSkills = [Skl#skl_prac{lev = Lev, exp = Exp} || Skl = #skl_prac{} <- Skills],
                          NewMSkill = MSkill#m_skill{skill_prac = NewSkills, is_open_skl_prac = ?true},
                          NewRole = Role#role{m_skill = NewMSkill},
                          skill_prac:push_skl_prac(NewRole),
                          Reply = "冒险技能设置成功",
                          {reply, Reply, NewRole}
                  end
        }
        ,#gm_cmd{
            cmd = "设饱食度"
            ,args = [
                {int, "饱食度", 0}
            ]
            ,desc = "设置饱食度"
            ,do = fun([Val], Role) ->
                    satiety:gm(Role, {set, Val})
                  end
        }
        ,#gm_cmd{
            cmd = "重置远航"
            ,args = []
            ,desc = "重置远航商人"
            ,do = fun([], Role) ->
                     shipping:gm_reset_shipping(Role)
                  end
        }
        ,#gm_cmd{
            cmd = "金币市场物品"
            ,args = [{int, "物品基础ID", 0}]
            ,desc = "查询金币市场物品数据"
            ,do = fun([BaseId], _Role) ->
                     Reply = market_tests:gm_gold_lookup(BaseId),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "金币市场类别"
            ,args = [{int, "一级类别", 1}
                     ,{int, "二级类别", 2}
                    ]
            ,desc = "查询金币市场物品数据"
            ,do = fun([Catalg1, Catalg2], Role) ->
                     Reply = market_tests:gm_gold_lookup_items(Catalg1, Catalg2, Role),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "金币刷新"
            ,args = []
            ,desc = "金币市场刷新"
            ,do = fun([], _Role) ->
                     Reply = market_tests:gm_gold_refresh(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "设金市物品"
            ,args = [
                     {int, "物品基础ID", 0}
                     , {int, "当前价格", -1}
                     , {int, "起始价格", -1}
                     , {int, "当前库存", -1}
                    ]
            ,desc = "设置金币市场物品数据"
            ,do = fun([BaseId, CurPrice, InitPrice, Stock], Role) ->
                     Reply = market_tests:gm_gold_set(BaseId, CurPrice, InitPrice, Stock, Role),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "回购列表"
            ,args = []
            ,desc = "银币市场回收列表"
            ,do = fun([], _Role) ->
                     Reply = market_tests:gm_check_recover(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "回购"
            ,args = []
            ,desc = "银币市场回购"
            ,do = fun([], _Role) ->
                     Reply = market_tests:gm_recover(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "银币市场价格"
            ,args = []
            ,desc = "银币市场价格"
            ,do = fun([], _Role) ->
                     Reply = market_tests:gm_silver_print_price(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "重置银币市场"
            ,args = []
            ,desc = "重置银币"
            ,do = fun([], _Role) ->
                     Reply = market_tests:gm_silver_reset(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "开启封妖"
            ,args = []
            ,desc = "开启封妖"
            ,do = fun([], Role) ->
                     Reply = treasure:gm_start_ghost_box(Role),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "查看封妖"
            ,args = [{int, "地图基础Id", 10002}]
            ,desc = "查看封妖"
            ,do = fun([MapBaseId], _Role) ->
                     Reply = treasure:gm_lookup_units(MapBaseId),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "清除封妖"
            ,args = []
            ,desc = "清除封妖"
            ,do = fun([], _Role) ->
                     Reply = treasure:gm_clean_ghost_box(),
                     {reply, Reply}
                  end
        }
        ,#gm_cmd{
            cmd = "段位赛下阶段"
            ,args = []
            ,desc = "段位赛进入下阶段"
            ,do = fun([], _Role) ->
                     qualifying_mgr:m(timeout),
                     ok
             end
         }
        ,#gm_cmd{
            cmd = "星辰宝贝下阶段"
            ,args = []
            ,desc = "星辰宝贝下阶段"
            ,do = fun([], _Role) ->
                     camp_guild_bady:m(),
                     ok
             end
         }
        ,#gm_cmd{
            cmd = "巅峰对决下阶段"
            ,args = []
            ,desc = "巅峰对决下阶段"
            ,do = fun([], _Role) ->
                     top_compete_mgr:m(timeout),
                     ok
             end
         }
        ,#gm_cmd{
            cmd = "武道大会下阶段"
            ,args = []
            ,desc = "武道大会下阶段"
            ,do = fun([], _Role) ->
                     hero_mgr:m(),
                     ok
             end
         }
        ,#gm_cmd{
            cmd = "婚礼下阶段"
            ,args = []
            ,desc = "婚礼进入下阶段"
            ,do = fun([], _Role) ->
                     wedding_mgr:m(),
                     ok
             end
         }
        ,#gm_cmd{
            cmd = "清空结婚状态"
            ,args = [
            ]
            ,desc = "清空结婚状态"
            ,do = fun([], Role = #role{id = RoleId}) ->
                    ets:delete(lover, RoleId),
                    dets:delete(lover, RoleId),
                    {ok, Role#role{m_wedding = #m_wedding{}}}
            end
        }
        ,#gm_cmd{
            cmd = "宠物祝福"
            ,args = []
            ,desc = "宠物祝福下阶段"
            ,do = fun([], _Role) ->
                          meet_pet:m(),
                          {reply, "宠物祝福进入下阶段"}
            end
        }
        ,#gm_cmd{
            cmd = "清空宠物祝福"
            ,args = []
            ,desc = "清空宠物祝福状态"
            ,do = fun([], Role) ->
                          case meet_pet:gm_clean_meet_pet(Role) of
                              {ok, NewRole} ->
                                  ?DEBUG("成功清空宠物祝福状态"),
                                  {reply, "成功清空宠物祝福状态", NewRole};
                              {false, _Msg} ->
                                  ?DEBUG("~ts", [_Msg]),
                                  {reply, "成功清空宠物祝福状态"};
                              _False ->
                                  ?DEBUG("成功清空宠物祝福状态:~w", [_False]),
                                  {reply, "成功清空宠物祝福状态"}
                          end
            end
        }
        ,#gm_cmd{
            cmd = "删除夫妻任务"
            ,args = [
            ]
            ,desc = "删除夫妻任务"
            ,do = fun([], Role = #role{m_quest = MQuest = #m_quest{quest = Quests, quest_marriage = QMarriage}}) ->
                          case lists:keyfind(?quest_sec_type_marriage, #quest.sec_type, Quests) of
                              Quest = #quest{} ->
                                  NewRole = quest:del_quest(Quest, Role),
                                  %% NewRole = var:del_var(DelRole, day_five, ?var_day_five_quest_marriage),
                                  {reply, "成功删除夫妻任务", NewRole};
                              _False ->
                                  ?DEBUG("删除夫妻任务~w", [_False]),
                                  NewRole = Role#role{m_quest = MQuest#m_quest{quest_marriage =
                                      QMarriage#quest_marriage{round = 0}}
                                  },
                                  {reply, "没有夫妻任务可以删除", NewRole}
                          end
            end
        }
        ,#gm_cmd{
            cmd = "删除情缘任务"
            ,args = [
            ]
            ,desc = "删除情缘任务"
            ,do = fun([], Role = #role{m_quest = MQuest = #m_quest{quest = Quests, quest_couple = QMarriage}}) ->
                          case lists:keyfind(?quest_sec_type_couple, #quest.sec_type, Quests) of
                              Quest = #quest{} ->
                                  NewRole = quest:del_quest(Quest, Role),
                                  %% NewRole = var:del_var(DelRole, day_five, ?var_day_five_quest_marriage),
                                  {reply, "成功删除情缘任务", NewRole};
                              _False ->
                                  ?DEBUG("删除情缘任务~w", [_False]),
                                  NewRole = Role#role{m_quest = MQuest#m_quest{quest_couple =
                                      QMarriage#quest_couple{round = 0}}
                                  },
                                  {reply, "没有情缘任务可以删除", NewRole}
                          end
            end
        }
        ,#gm_cmd{
            cmd = "清种植任务"
            ,args = [
            ]
            ,desc = "清种植任务"
            ,do = fun([], Role = #role{m_quest = MQuest = #m_quest{quest = Quests, quest_plant = Plant = #quest_plant{unit_id = UnitId, pos = {Map, X, Y}}}}) ->
                    Role1 = Role#role{
                        m_quest = MQuest#m_quest{
                            quest_plant = Plant#quest_plant{
                                round = 0
                                ,quest_id = 0
                                ,unit_id = 0
                                ,phase = 0
                                ,last_commited = 0
                                ,last_accepted = 0
                            }
                        }
                    },
                    Role2 = case UnitId of
                        0 -> Role1;
                        _ -> plot_quest:remove_task_unit(Role1, [{create_unit, UnitId, UnitId, {point, Map, X, Y}, 0, "stand"}])
                    end,
                    case lists:keyfind(?quest_sec_type_plant, #quest.sec_type, Quests) of
                        Quest = #quest{} ->
                            NewRole = quest:del_quest(Quest, Role2),
                            quest_plant:push(NewRole, 10224),
                            {reply, "成功删除种植任务", NewRole};
                        _False ->
                            quest_plant:push(Role2, 10224),
                            {reply, "没有种植任务可以删除", Role2}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "删除师徒任务"
            ,args = [
            ]
            ,desc = "删除师徒任务"
            ,do = fun([], Role = #role{m_quest = MQuest = #m_quest{quest = Quests, quest_teacher = QTeacher}}) ->
                          case lists:keyfind(?quest_sec_type_teacher, #quest.sec_type, Quests) of
                              Quest = #quest{} ->
                                  NewRole = quest:del_quest(Quest, Role),
                                  %% NewRole = var:del_var(DelRole, day_five, ?var_day_five_quest_marriage),
                                  {reply, "成功删除师徒任务", NewRole};
                              _False ->
                                  ?DEBUG("删除师徒任务~w", [_False]),
                                  NewRole = Role#role{m_quest = MQuest#m_quest{quest_teacher =
                                      QTeacher#quest_teacher{round = 0, stats = []}}
                                  },
                                  {reply, "没有师徒任务可以删除", NewRole}
                          end
            end
        }
        ,#gm_cmd{
            cmd = "清空结婚排行榜"
            ,args = [
                {int, "1"}
            ]
            ,desc = "清空结婚排行榜"
            ,do = fun([Type], _Role) ->
                    wedding_rank:clean_rank(Type),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "结婚排行榜称号"
            ,args = [
            ]
            ,desc = "结婚排行榜称号"
            ,do = fun([], _Role) ->
                    wedding_mgr:info(gm_rank_honor),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "正常状态"
            ,args = [
            ]
            ,desc = "正常状态"
            ,do = fun([], Role) ->
                    {ok, Role#role{s_event = ?event_normal}}
            end
        }
        ,#gm_cmd{
            cmd = "清段位赛次数"
            ,args = [
            ]
            ,desc = "清段位赛次数"
            ,do = fun([], #role{id = RoleId}) ->
                    qualifying_mgr:clean_count(RoleId),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "设段位赛积分"
            ,args = [
                {int, "1000"}
            ]
            ,desc = "设置段位赛积分"
            ,do = fun([Point], Role) when Point >= 0 andalso Point =< 11400 ->
                    qualifying_mgr:set_point(Role, Point),
                    ok;
                (_, _Role) ->
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "段位赛赛季奖励"
            ,args = [
            ]
            ,desc = "段位赛赛季奖励"
            ,do = fun([], _Role)->
                    qualifying_mgr:info(calc_final_reward),
                    ok;
                (_, _Role) ->
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "段位赛匹配测试"
            ,args = []
            ,desc = "段位赛匹配测试"
            ,do = fun([], Role = #role{id = Id, name = Name, sex = Sex, classes = Classes, lev = Lev, s_looks = Looks}) ->
                    I = {Id, Name, Sex, Classes, Lev, 1, 1150, Looks},
                    Ainfo = [I, I, I],
                    Binfo = [I, I, I],
                    role:link_send(Role, 13503, {1, Ainfo, Binfo}),
                    ok
             end
         }
        ,#gm_cmd{
            cmd = "设活跃度"
            ,args = [
                     {int, "活跃度", 0}
            ]
            ,desc = "设置活跃度"
            ,do = fun([Val], Role) ->
                    agenda:gm(Role, {set_activity, Val})
             end
         }
        ,#gm_cmd{
            cmd = "清活跃奖励"
            ,args = [
            ]
            ,desc = "清空活跃度奖励"
            ,do = fun(_, Role) ->
                    agenda:gm(Role, clear_reward)
             end
         }
         ,#gm_cmd{
             cmd = "发邮件"
             ,args = [
                 {string, "标题", "标题"}
                 ,{string, "内容", "内容"}
                 ,{string, "物品", "[]"}
                 ,{int, "0阅后删除，1阅后一天删", 0}
             ]
             ,desc = "给自己发没物品的邮件"
             ,do = fun([Title, Content, ItemStr, DelType], Role) ->
                     case util:string_to_term(ItemStr) of
                         {error, Err} ->
                             {reply, util:flist("命令的参数格式不正确: ~w", [Err])};
                         {ok, Item} ->
                             mail:send(Role, #{title => Title, content => Content, items => Item, del_type => DelType}),
                             ok
                     end
             end
         }
        ,#gm_cmd{
            cmd = "世界boss奖励"
            ,args = [
                {int, "1000"}
            ]
            ,desc = "发对应世界boss的奖励"
            ,do = fun([BaseId], _Role) ->
                    world_boss ! {reward, BaseId},
                    ok;
                (_, _Role) ->
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "世界boss复活"
            ,args = [
                {int, "1000"}
            ]
            ,desc = "复活指定世界boss"
            ,do = fun([BaseId], _Role) ->
                    world_boss ! {respawn, BaseId},
                    ok;
                (_, _Role) ->
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "通过图片"
            ,args = [
                {int, "图片id"}
            ]
            ,desc = "审核图片通过"
            ,do = fun([N], _Role = #role{id = Id}) ->
                    friend_zone:audit_photo(Id, N, 1),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "上传图片"
            ,args = [
            ]
            ,desc = "上传图片"
            ,do = fun(_, _Role = #role{id = Id}) ->
                    friend_zone ! {update, photo, Id},
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "不通过图片"
            ,args = [
                {int, "图片id"}
            ]
            ,desc = "审核图片不通过"
            ,do = fun([N], _Role = #role{id = Id}) ->
                    friend_zone:audit_photo(Id, N, 2),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "删除图片"
            ,args = [
            ]
            ,desc = "删除图片"
            ,do = fun(_, _Role = #role{id = Id}) ->
                    friend_zone ! {del_photo, Id},
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "清签到"
            ,args = [
            ]
            ,desc = "清签到奖励"
            ,do = fun(_, Role) ->
                    checkin:gm(Role, clear_everyday)
            end
        }
        ,#gm_cmd{
            cmd = "7天登录"
            ,args = [
            ]
            ,desc = "生成7天登录数据"
            ,do = fun(_, Role) ->
                    checkin:gm(Role, gen_seven)
            end
        }
        ,#gm_cmd{
            cmd = "职业挑战"
            ,args = [
            ]
            ,desc = "职业挑战"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(classes_challenge, timeout)
            end
        }
        ,#gm_cmd{
            cmd = "接受职业挑战"
            ,args = [
            ]
            ,desc = "接受职业挑战"
            ,do = fun([], Role) ->
                    classes_challenge:accept(Role)
            end
        }
        ,#gm_cmd{
            cmd = "清职业挑战"
            ,args = [
            ]
            ,desc = "清职业挑战"
            ,do = fun([], Role) ->
                    classes_challenge:gm(Role, clear)
            end
        }
        ,#gm_cmd{
            cmd = "清勇者试炼"
            ,args = [
            ]
            ,desc = "清勇者试炼"
            ,do = fun([], Role) ->
                    brave_trial:gm(Role, clear)
            end
        }
        ,#gm_cmd{
            cmd = "赛龙舟公告"
            ,args = [
            ]
            ,desc = "赛龙舟公告"
            ,do = fun([], _Role) ->
                    camp_dragon_boat:gm(announce)
            end
        }
        ,#gm_cmd{
            cmd = "清龙舟"
            ,args = [
            ]
            ,desc = "清龙舟次数"
            ,do = fun([], Role) ->
                    {ok, Role#role{m_camp_dragon_boat = #m_camp_dragon_boat{}}}
            end
        }
        ,#gm_cmd{
            cmd = "赛龙舟"
            ,args = [
            ]
            ,desc = "赛龙舟状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(camp_dragon_boat, timeout)
            end
        }
        ,#gm_cmd{
            cmd = "幻境寻宝"
            ,args = [
            ]
            ,desc = "幻境寻宝活动状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(fairyland, timeout)
            end
        }
        ,#gm_cmd{
            cmd = "活动重载"
            ,args = []
            ,desc = "重载活动数据"
            ,do = fun([], _Role) ->
                    role_group:apply(world, {campaign_time, push_time_info, []}),
                    campaign_mgr:reload(),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "lookfun"
            ,args = [
                {atom, "模块名"}
                ,{atom, "方法名"}
                ,{string, "参数", "[]"}
            ]
            ,desc = "查看方法返回"
            ,do = fun([Mod, F, A], Role) ->
                    {ok, Args} = util:string_to_term(A),
                    Fun1 = fun(role) -> Role;
                        (A1) -> A1
                    end,
                    Ret = erlang:apply(Mod, F, [Fun1(A1) || A1 <- Args]),
                    {reply, util:flist("结果:~w", [Ret])}
            end
        }


        ,#gm_cmd{
            cmd = "参与幻境寻宝"
            ,args = [
            ]
            ,desc = "参与幻境寻宝"
            ,do = fun([], Role) ->
                    fairyland:join(Role)
            end
        }
        ,#gm_cmd{
            cmd = "退出幻境寻宝"
            ,args = [
            ]
            ,desc = "退出幻境寻宝"
            ,do = fun([], Role) ->
                    fairyland:quit(Role)
            end
        }
        ,#gm_cmd{
            cmd = "幻境跳转"
            ,args = [
                {int, "第几层"}
            ]
            ,desc = "幻境寻宝跳转"
            ,do = fun([Floor], Role) ->
                    fairyland:gm(Role, {teleport, Floor})
            end
        }
        ,#gm_cmd{
            cmd = "幻境boss"
            ,args = [
            ]
            ,desc = "更新幻境boss"
            ,do = fun([], _Role) ->
                    fairyland ! gen_boss,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "幻境钥匙"
            ,args = [
                {int, "数量"}
            ]
            ,desc = "获取幻境钥匙"
            ,do = fun([Num], Role) ->
                    fairyland:gm(Role, {gen_keys, Num})
            end
        }
        ,#gm_cmd{
            cmd = "智力闯关"
            ,args = [
            ]
            ,desc = "智力闯关状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(examination, timeout)
            end
        }
        ,#gm_cmd{
            cmd = "星座挑战"
            ,args = [
            ]
            ,desc = "星座状态切换"
            ,do = fun([], _Role) ->
                    gen_fsm:send_event(constellation, timeout),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "星座刷新"
            ,args = [
            ]
            ,desc = "星座挑战刷新怪物"
            ,do = fun([], _Role) ->
                    constellation ! refresh_units,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "清星座首杀"
            ,args = [
            ]
            ,desc = "清理星座首杀记录"
            ,do = fun([], _Role) ->
                    ets:delete_all_objects(constellation_first),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "勇士下阶段"
            ,args = [
            ]
            ,desc = "勇士战场下阶段"
            ,do = fun([], _Role) ->
                     warrior_mgr:m(), ok
            end
        }
        ,#gm_cmd{
            cmd = "设气血"
            ,args = [
                {int, "气血比"}
            ]
            ,desc = "设置当前的气血比"
            ,do = fun([Val], Role = #role{hp_max = HpMax}) ->
                    Role1 = Role#role{hp = round(HpMax * Val / 100)},
                    attr:push_10011(Role1),
                    {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "设充值"
            ,args = [
                {int, "充值额度"}
            ]
            ,desc = "设置当前的充值额度"
            ,do = fun([Val], Role) ->
                    Role1 = Role#role{charge = Val},
                    {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "充值"
            ,args = [
                {int,  "钻石", 100}
                ,{int,  "充值类型", 0}
            ]
            ,desc = "充值指定钻石"
            ,do = fun([Gold, ChargeType], #role{id = {Rid, P, Z}, channel_reg = ChannelReg, account = Account, name = Name, lev = Lev, classes = Classes}) ->
                    ?DEBUG("充值执行"),
                    Sn = lists:concat([p, date:unixtime(ms) * 100000000, Rid]),
                    _Ret = db:exec("insert into charge(sn, type, status, gold, charge_type, money, account, rid, platform, zone_id, channel_reg, name, classes, lev, is_test, ts) values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [Sn, 1, 0, Gold, ChargeType, Gold, Account, Rid, P, Z, ChannelReg, Name, Classes, Lev, 1, date:unixtime()]),
                    charge:notice(Rid, P, Z, Sn),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "提示"
            ,args = [
            ]
            ,desc = "测试提示"
            ,do = fun([], #role{id = RoleId, name = RoleName}) ->
                    Msg = notice:format("~ts消耗了~ts，但是由于~ts不足~w，所以没法获得~ts", [{role_1, RoleId, RoleName}, {assets_1, ?assets_coin, 500}, {string_2, ?color_yellow, "智商"}, 50, {item_2, 20000}]),
                    notice:send(conn_pid, ?notice_up, Msg),
                    notice:cast(all, ?notice_hearsay_top, Msg),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "重置神秘"
            ,args = [
            ]
            ,desc = "重置神秘商店"
            ,do = fun([], Role) ->
                    store:reset_role(Role)
            end
        }
        ,#gm_cmd{
            cmd = "刷新活动怪"
            ,args = [
            ]
            ,desc = "刷新活动怪"
            ,do = fun([], _Role) ->
                    campaign_unit ! make_unit,
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "打群架"
            ,args = [
            ]
            ,desc = "打自己（克隆人）"
            ,do = fun(_, Role = #role{classes = _Rclasses}) ->
                   %% L = [1, 3, 5] -- [Rclasses],
                   %% [H | T] = L,
                   %% [H1 | _] = T,
                    {ok, F1} = role_convert:to(fighter, Role),
                    {ok, F2} = role_convert:to(fighter_clone, Role),
                    {ok, F3} = role_convert:to(fighter_clone, Role),
                    {ok, F4} = role_convert:to(fighter_clone, Role),
                    {ok, F5} = role_convert:to(fighter_clone, Role),

                    {ok, F6} = role_convert:to(fighter_clone, Role),
                    {ok, F7} = role_convert:to(fighter_clone, Role),
                    {ok, F8} = role_convert:to(fighter_clone, Role),
                    {ok, F9} = role_convert:to(fighter_clone, Role),
                    {ok, F10} = role_convert:to(fighter_clone, Role),
                    combat_mgr:start_combat(?combat_type_unknown, [F1, F2, F3, F4, F5], [F6, F7, F8, F9, F10]),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "cmd"
            ,args = [
                {int, "命令号"}
                ,{string, "参数", "{}"}
            ]
            ,desc = "执行服务端命令(模拟客户端发送消息)"
            ,do = fun([Code, ArgStr], _Role) ->
                    case util:string_to_term(ArgStr) of
                        {error, Err} ->
                            {reply, util:flist("命令的参数格式不正确: ~w", [Err])};
                        {ok, Data} ->
                            case mapping:module(game_server, Code) of
                                {error, _Reason} ->
                                    {reply, "模块映射失败，请检查命令号是否正确"};
                                {ok, _, _, Parser, Mod} ->
                                    ?INFO("Data:~w", [Data]),
                                    case Parser:pack(cli, Code, Data) of
                                        {ok, <<_A1:32, _A2:16, Bin/binary>>} ->
                                            ?INFO("==============~w", [{Parser, Mod, Code, Bin}]),
                                            role:rpc(self(), Parser, Mod, Code, Bin),
                                            ok;
                                        _Err ->
                                            ?ERR("打包数据出错，请检查参数格式是否正确:~w", [_Err]),
                                            {reply, "打包数据出错，请检查参数格式是否正确"}
                                    end
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "协议监控"
            ,args = [
                {atom, "状态", true}
            ]
            ,desc = "协议请求发送监控 true | false"
            ,do = fun([Debug], _Role) ->
                    get(conn_pid) ! {debug, Debug},
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "测试注册"
            ,args = [
            ]
            ,desc = "测试注册"
            ,do = fun([], Role) ->
                    log_account:update(Role),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "加竞技场魂"
            ,args = [
                {int, "魂数"}
            ]
            ,desc = "增加竞技场魂"
            ,do = fun([Val], Role) ->
                    Soul = var:get_var(Role, other, ?var_other_arena_soul, 0),
                    NewSoul = Soul + Val,
                    Role1 = var:set_var(Role, other, ?var_other_arena_soul, NewSoul),
                    case arena_mgr:init_panel(Role) of
                        {true, Cup, Enemy, ArenaLog} ->
                            role:link_send(Role1, 12200, {Cup, NewSoul, Enemy, ArenaLog}),
                            {ok, Role1};
                        _ ->
                            {reply, "增加失败"}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "竞技场roll"
            ,args = [
                {int, "roll次数"}
            ]
            ,desc = "增加竞技场roll点次数"
            ,do = fun([Val], Role = #role{m_arena = Marena}) ->
                    NewMarena = Marena#m_arena{roll_time = Val},
                    Role1 = Role#role{m_arena = NewMarena},
                    arena_mgr:push_count(Role1),
                    {ok, Role1}
            end
        }
        ,#gm_cmd{
            cmd = "进跨服"
            ,args = [
            ]
            ,desc = "进入跨服地图"
            ,do = fun([], Role) ->
                    case c_trip_mgr:enter(Role) of
                        {ok, NewRole} ->
                            {ok, NewRole};
                        {false, Reason} ->
                            {reply, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "退跨服"
            ,args = [
            ]
            ,desc = "退出跨服地图"
            ,do = fun([], Role) ->
                    case c_trip_mgr:exit(Role) of
                        {ok, NewRole} ->
                            {ok, NewRole};
                        {false, Reason} ->
                            {reply, Reason}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "重置胜利之路"
            ,args = [
            ]
            ,desc = "重置胜利之路"
            ,do = fun([], Role = #role{m_arena = Marena}) ->
                    RollGraph = arena_mgr:make_graph(Role), 
                    NewMarena = Marena#m_arena{roll_graph = RollGraph, roll_id = 0},
                    NewRole = Role#role{m_arena = NewMarena},
                    arena_mgr:push_graph(NewRole),
                    {ok, NewRole}
            end
        }
        ,#gm_cmd{
            cmd = "协议请求"
            ,args = [
                {int, "协议号"}
                ,{string, "协议请求附带值 举例=>1,abc", ""}
            ]
            ,desc = "协议请求消息(服务器端测试使用)"
            ,do = fun([Code, Info], Role) ->
                    case mapping:module(game_server, Code) of
                        {ok, _, object, Parser, Mod} ->
                            %% 协议请求字符转换
                            L = string:tokens(Info, ";"),
                            Fun = fun(A) ->
                                    case catch list_to_integer(A) of
                                        {'EXIT', _} ->
                                            case catch list_to_float(A) of
                                                {'EXIT', _} ->
                                                    case util:string_to_term(A) of
                                                        {ok, Term} when is_list(Term) orelse is_tuple(Term) ->
                                                            Term;
                                                        _ ->
                                                            list_to_binary(A)
                                                    end;
                                                Float ->
                                                    Float
                                            end;
                                        Int ->
                                            Int
                                    end
                            end,
                            ArgL = lists:map(Fun, L),
                            Tuple = list_to_tuple(ArgL),
                            case Parser:pack(cli, Code, Tuple) of
                                {ok, <<_A1:32, _A2:16, Bin/binary>>} ->
                                    role:rpc(Role#role.pid, Parser, Mod, Code, Bin),
                                    ok;
                                _ ->
                                    {reply, "非法参数"}
                            end;
                        _ ->
                            {reply, "非法协议号"}
                    end
            end
        }
        ,#gm_cmd{
            cmd = "播放剧情"
            ,args = [
                {int, "剧情ID"}
                ,{int, "第几步", 1}
            ]
            ,desc = "播放指定剧情"
            ,do = fun([Id, Num], Role = #role{m_plot = MPlot = #m_plot{play_list = PlayL, do_list = DoL}}) ->
                    case lists:keyfind(Id, #plot.id, DoL) of
                        #plot{act_idx = ActIdx} when ActIdx > 0 -> ok;
                        Plot = #plot{} ->
                            NRole = Role#role{m_plot = MPlot#m_plot{play_list = PlayL ++ [Id], do_list = lists:keyreplace(Id, #plot.id, DoL, Plot#plot{act_idx = Num})}},
                            {ok, plot_act:continue(NRole)};
                        _ ->
                            case plot_data:get(Id) of
                                #plot_trigger{type = ?plot_type_common} ->
                                    Plot = #plot{id = Id, act_idx = Num},
                                    NRole = Role#role{m_plot = MPlot#m_plot{play_list = PlayL ++ [Id], do_list = [Plot | DoL]}},
                                    {ok, plot_act:continue(NRole)};
                                _ ->
                                    {reply, ?T("剧情基础数据不存在")}
                            end
                    end
            end
        }
        ,#gm_cmd{
            cmd = "协议推送"
            ,args = [
                {int, "协议号"}
                ,{string, "协议请求附带值 举例=>1;abc", ""}
            ]
            ,desc = "推送请求消息(客户端测试使用)"
            ,do = fun([Code, Info], _Role) ->
                    L = string:tokens(Info, ";"),
                    Fun = fun(A) ->
                            case catch list_to_integer(A) of
                                {'EXIT', _} ->
                                    case catch list_to_float(A) of
                                        {'EXIT', _} ->
                                            case util:string_to_term(A) of
                                                {ok, Term} when is_list(Term) orelse is_tuple(Term) ->
                                                    Term;
                                                _ ->
                                                    list_to_binary(A)
                                            end;
                                        Float ->
                                            Float
                                    end;
                                Int ->
                                    Int
                            end
                    end,
                    ArgL = lists:map(Fun, L),
                    Tuple = list_to_tuple(ArgL),
                    sys_conn:pack_send(Code, Tuple),
                    ok
            end
        }
        ,#gm_cmd{
            cmd = "获取buff"
            ,args = [
                {int, "buffid"}
            ]
            ,desc = "给角色增加一个buff"
            ,do = fun ([Buffid], Role) ->
                buff:add(Role, Buffid)
            end
        }
		,#gm_cmd{
            cmd = "镶嵌宝石"
            ,args = [
                {int, "lev"}
            ]
            ,desc = "给角色镶嵌宝石"
            ,do = fun ([Lev], Role = #role{p_eqm = #package{items = Items}, classes = Classes}) ->
                    case gm_srv_data:get_data({Lev, Classes}) of
                        #{stone_list := List} -> 
                            NewRole = dembed(Items, List, Role),
                            NewRole1 = attr:calc_and_push(NewRole),
                            {ok, NewRole1};
                        _ ->
                            {reply, ?T("无法找到镶嵌数据")}
                    end
            end
        }
    ].

%% @doc 执行命令
-spec do(bitstring(), #role{}) -> {reply, bitstring()} | {reply, bitstring(), #role{}}.
do(CmdStr, Role) ->
    case string:tokens(CmdStr, " ") of
        [] -> {reply, {help(cmds())}};
        [Cmd | A] ->
            case lists:keyfind(Cmd, #gm_cmd.cmd, cmds()) of
                false ->
                    {reply, {util:flist("不支持的命令: ~ts~n", [Cmd])}};
                GmCmd = #gm_cmd{do = Do, args = ArgDefine} ->
                    case parse_args(ArgDefine, A, []) of
                        {error, Reason} ->
                            {reply, {util:flist("命令[~ts]执行失败: ~ts~n命令说明:~ts~n", [Cmd, Reason, help([GmCmd])])}};
                        {ok, Args} ->
                            case catch Do(Args, Role) of
                                ok -> ok;
                                {ok, NewRole} -> {reply,{util:flist("命令[~ts]执行成功~n", [Cmd])}, NewRole};
                                {false, Msg} -> {reply, {util:flist("~ts~n", [Msg])}};
                                {error, Msg} -> {reply, {util:flist("<SRV> ~ts~n", [Msg])}};
                                {reply, Msg} -> {reply, {util:flist("~ts~n", [Msg])}};
                                {reply, Msg, NewRole} -> {reply, {util:flist("~ts~n", [Msg])}, NewRole};
                                Err ->
                                    ?ERR("命令[~ts]执行失败: ~w", [Cmd, Err]),
                                    {reply, {util:flist("[SRV]命令[~ts]执行失败~n", [Cmd])}}
                            end
                    end
            end
    end.

%% %% 执行命令组
%% do_cmds([], Role) ->
%%     {ok, Role};
%% do_cmds([{Cmd, Args} | T], Role) ->
%%     case lists:keyfind(Cmd, #gm_cmd.cmd, cmds()) of
%%         false ->
%%             sys_conn:pack_send(9900, {util:fbin(?T(<<"不支持的命令: ~ts">>), [Cmd])}),
%%             do_cmds(T, Role);
%%         #gm_cmd{do = Do} ->
%%             case catch Do(Args, Role) of
%%                 ok -> do_cmds(T, Role);
%%                 {ok, NewRole} -> do_cmds(T, NewRole);
%%                 {reply, Msg, NewRole} ->
%%                     sys_conn:pack_send(9900, {util:fbin("<SRV> ~ts", [Msg])}),
%%                     do_cmds(T, NewRole);
%%                 Err ->
%%                     ?ERR("命令[~ts]执行失败: ~w", [Cmd, Err]),
%%                     do_cmds(T, Role)
%%             end
%%     end.

%% 解析参数
parse_args([], _, L) -> {ok, lists:reverse(L)};
parse_args([{_Type, _Desc, DefVal} | T], [], L) -> %% 带默认值处理
    parse_args(T, [], [DefVal | L]);
parse_args(_, [], _L) -> {error, "参数不完整"};
parse_args([{Type, Desc, _} | T], Args, L) ->
    parse_args([{Type, Desc} | T], Args, L);
parse_args([{int, Desc} | T], [V | Args], L) ->
    case catch list_to_integer(V) of
        {'EXIT', _} ->
            {error, util:cn("参数[~ts]无法转换成int", [Desc])};
        A ->
            parse_args(T, Args, [A | L])
    end;
parse_args([{atom, _Desc} | T], [V | Args], L) ->
    parse_args(T, Args, [list_to_atom(V) | L]);
parse_args([{float, Desc} | T], [V | Args], L) ->
    case catch list_to_float(V) of
        {'EXIT', _} ->
            {error, util:cn("参数[~ts]无法转换成float", [Desc])};
        A ->
            parse_args(T, Args, [A | L])
    end;
parse_args([{bitstring, Desc} | T], [V | Args], L) ->
    case catch list_to_bitstring(V) of
        {'EXIT', _} ->
            {error, util:cn("参数[~ts]无法转换成bitstring", [Desc])};
        A ->
            parse_args(T, Args, [A | L])
    end;
parse_args([{_, _} | T], [V | Args], L) ->
    parse_args(T, Args, [V | L]).

%%----------------------------------------------------
%% 私有函数
%%----------------------------------------------------

%% match_type_to_code("friend") -> ?matching_friend;
%% match_type_to_code("fate") -> ?matching_fate;
%% match_type_to_code("pve") -> ?matching_pve;
%% match_type_to_code(_) -> all.

%% 生成帮助信息
help(Cmds) -> lists:concat(lists:reverse(do_help(Cmds, []))).
do_help([], L) -> L;
do_help([#gm_cmd{cmd = Cmd, args = Args, desc = Desc} | T], L) ->
    %% S = lists:concat(["> 说明：", Desc, ":\n  GM命令：", Cmd, lists:concat([" [" ++ to_help_args(A) ++ "]" || A <- Args]), "\n"]),
    S = lists:concat(["<color=#393>", Cmd, "</color>", lists:concat([" [<color=#393>" ++ to_help_args(A) ++ "</color>]" || A <- Args]), " ", Desc, "\n"]),
    do_help(T, [S | L]).
to_help_args({_, Desc}) ->
    lists:concat([Desc, ",必须项"]);
to_help_args({_, Desc, DefVal}) ->
    lists:concat([Desc, ",默认值(", util:to_list(DefVal),")"]).

%%--------------------------------------
%% 变身GM命令处理
%%--------------------------------------
gm(Id, Role = #role{classes = Classes, p_eqm = #package{items = OldEqms}}) ->
    case gm_srv_data:get({Id, Classes}) of
        #{lev := Lev, eqm := Eqm, enchant := Enchant, skill_lev := SkillLev, skill_prac := SkillPracLev, wing := WingLev} ->
            EqmItems = make_eqm(Eqm, Enchant, Role, []),
            Role0 = Role#role{p_eqm = package:init(eqm)},
            Role1 = #role{p_eqm = #package{items = NewEqms}} = puton_eqm(EqmItems, Role0),
            package:push_gain([{?package_type_eqm, NewEqms, OldEqms, []}], Role1),
            Role2 = Role1#role{lev = Lev, is_gain = true},
            Role3 = make_skill(SkillLev, Role2),
            Role4 = make_skill_prac(SkillPracLev, Role3),
            Role5 = make_wing(WingLev, Role4),
            NewRole = attr:calc_and_push(Role5),
            LookRole = looks:calc(NewRole),
            looks:update_looks(Role, LookRole),
            role_gain:push_exp(LookRole),
            map:role_update(LookRole),
            {ok, LookRole};
        _ ->
            {reply, "查找不到数据"}
    end.

%% 生成技能
make_skill(SkillLev, Role = #role{lev = Lev, m_skill = MSkill = #m_skill{skills = Skills}}) ->
    MinSkillLev = min(SkillLev, Lev),
    Fun = fun({SkillId, OldSkillLev}, SkillList) ->
            case skill_data:get_role({SkillId, MinSkillLev}) of
                #role_base_skill{study_lev = StudyLev} when StudyLev =< Lev ->
                    [{SkillId, MinSkillLev} | SkillList];
                _ ->
                    [{SkillId, OldSkillLev} | SkillList]
            end
    end,
    NewSkills = lists:reverse(lists:foldl(Fun, [], Skills)),
    NewRole = Role#role{m_skill = MSkill#m_skill{skills = NewSkills}},
    role:link_send(NewRole, 10800, {NewSkills}),
    NewRole.

%% 生成修炼技能
make_skill_prac(SkillPracLev, Role = #role{}) ->
    Role1 = #role{m_skill = MSkill = #m_skill{selected_skl_prac = SklPracId, skill_prac = SkillPrac}}= skill_prac:level_up(Role),
    NewSkillPrac = [SklPrac#skl_prac{lev = SkillPracLev} || SklPrac <- SkillPrac],
    NewMSkill = MSkill#m_skill{skill_prac = NewSkillPrac},
    Role2 = Role1#role{m_skill = NewMSkill},
    role:link_send(Role2, 10805, {SklPracId, NewSkillPrac}),
    Role2.

%% 生成翅膀
make_wing(0, Role = #role{m_wing = Mwing}) ->
    NewMwing = Mwing#m_wing{grade = 0, growth = 0, star_lev = 0},
    Role1 = Role#role{m_wing = NewMwing},
    wing:push_wing(Role1),
    Role1;
make_wing(WingGrade, Role) ->
    case wing:update_wing(WingGrade, Role,true, true) of
        {ok, NewRole = #role{m_wing = Mwing}} -> 
            NewRole#role{m_wing = Mwing#m_wing{star_lev = 0}};
        _ -> Role
    end.

%% 生产道具
make_eqm([], _Enchant, _Role, L) -> L;
make_eqm([BaseId | T], Enchant, Role = #role{}, L) ->
    case item:make(BaseId, 0, 1) of
        {ok, [Item = #item{use_type = ?item_use_puton}]} ->
            Item1 = eqm_attr:calc_eqm(Item#item{enchant = Enchant}),
            make_eqm(T, Enchant, Role, [Item1 | L]);
        _ ->
            make_eqm(T, Enchant, Role, L)
    end.
puton_eqm([], Role) -> Role;
puton_eqm([Item = #item{type = Type} | T], Role = #role{p_eqm = PEqm = #package{items = Items, free_cell = FreeCell}}) ->
    EqmId = eqm:type_to_id(Type),
    EqmPos = eqm:type_to_pos(Type),
    NewItem = Item#item{id = EqmId, pos = EqmPos},
    puton_eqm(T, Role#role{p_eqm = PEqm#package{items = [NewItem | Items], free_cell = FreeCell -- [EqmPos]}}).

dembed([], _List, Role) -> Role;
dembed([Eqm = #item{attr = AttrList, lev = Lev, type = IType} | ItemList], List, Role = #role{p_eqm = Peqm}) ->
	case lists:keyfind(IType, 1, List) of
		{_, StoneId, StoneId2} ->
			AttrList1 = [Attr || Attr = #attr_base{type = Type} <- AttrList, Type =/= ?attr_type_hole],
			?DEBUG("DEMBED ~w~n",[StoneId]),
			%% 	Val1 = StoneId,
			%% 	Val2 = StoneId,
			%% 	Vals = [20801,20802,20803,20804,20805,20806,20807],
			%% 	Val1 = util:rand_list(Vals),
			%% 	Val2 = util:rand_list(Vals),
			HoleAttr = #attr_base{type = ?attr_type_hole, name = ?attr_hole_1, flag = 0, val = StoneId},
			HoleAttr1 = #attr_base{type = ?attr_type_hole, name = ?attr_hole_2, flag = 0, val = StoneId2},
			NewEqm = if 
				Lev >= 60 andalso StoneId2 =/= 0 ->
					Eqm#item{attr = [HoleAttr, HoleAttr1 | AttrList1]};
				Lev >= 30 ->
					Eqm#item{attr = [HoleAttr | AttrList1]};
				true ->
					Eqm
			end,
			{ok, NewPeqm, _} = package:fresh_item(Eqm, NewEqm, Peqm, Role),
			NewRole = Role#role{p_eqm = NewPeqm},
			dembed(ItemList, List, NewRole);
		_ ->
			AttrList1 = [Attr || Attr = #attr_base{type = Type} <- AttrList, Type =/= ?attr_type_hole],
			NewEqm = Eqm#item{attr = AttrList1},
			{ok, NewPeqm, _} = package:fresh_item(Eqm, NewEqm, Peqm, Role),
			NewRole = Role#role{p_eqm = NewPeqm},
			dembed(ItemList, List, NewRole)
	end.

-else.
cmds() -> [].
save() -> ok.
do(_Cmd, _Role) ->
    {reply, {"不支持的调用"}}.

-endif.
