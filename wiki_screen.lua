WikiScreen = Object:extend()
WikiScreen:implement(State)
WikiScreen:implement(GameObject)

function WikiScreen:init(name)
  self:init_state(name)
  self:init_game_object()
end

function WikiScreen:on_enter(from, level, loop, units, passives, shop_level, shop_xp)
  local from_name = type(from) == 'table' and from.name or from
  self.from = from_name

  if level == 'buy_screen' then
    level, loop, units, passives, shop_level, shop_xp = loop, units, passives, shop_level, shop_xp, nil
  end

  if not self.t then self.t = Trigger() end
  if self.from == 'buy_screen' or level ~= nil then
    self.from_params = {
      level = (type(level) == 'number' and level) or 1,
      loop = (type(loop) == 'number' and loop) or 0,
      units = (type(units) == 'table' and units) or {},
      passives = (type(passives) == 'table' and passives) or {},
      shop_level = (type(shop_level) == 'number' and shop_level) or 1,
      shop_xp = (type(shop_xp) == 'number' and shop_xp) or 0
    }
  else
    self.from_params = nil
  end

  camera.x, camera.y = gw/2, gh/2
  input:set_mouse_visible(true)

  self.main = Group()
  self.effects = Group()
  self.ui = Group():no_camera()

  self.selected_classes = {}
  self.selected_tier = nil

  self.all_classes = {
    'warrior', 'ranger', 'healer', 'conjurer', 'mage', 'nuker',
    'rogue', 'enchanter', 'psyker', 'curser', 'forcer', 'swarmer',
    'voider', 'sorcerer', 'mercenary', 'explorer'
  }

  self.all_units_sorted = {}
  for unit_name, _ in pairs(character_tiers) do
    table.insert(self.all_units_sorted, unit_name)
  end
  table.sort(self.all_units_sorted, function(a, b)
    local ta, tb = character_tiers[a] or 1, character_tiers[b] or 1
    if ta ~= tb then return ta < tb end
    return (character_names[a] or a) < (character_names[b] or b)
  end)

  -- Top Bar
  self.title_text = Text({{text = '[wavy_mid, fg]wiki & team planner', font = pixul_font, alignment = 'center'}}, global_text_tags)

  self.back_button = Button{group = self.ui, x = 32, y = 16, button_text = 'Back', fg_color = 'bg10', bg_color = 'bg', action = function()
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    self:go_back()
  end}

  self.clear_button = Button{group = self.ui, x = 440, y = 16, button_text = 'Clear', fg_color = 'red', bg_color = 'bg', action = function()
    input.m1.pressed = false
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    main:clear_planned_team()
    self:refresh_right_panel()
    self:refresh_unit_cards()
  end}

  self:build_filter_buttons()
  self:refresh_unit_cards()
  self:refresh_right_panel()
end

function WikiScreen:go_back()
  if self.from == 'buy_screen' then
    local p = self.from_params or {}
    local level = (type(p.level) == 'number' and p.level) or 1
    local loop = (type(p.loop) == 'number' and p.loop) or 0
    local units = (type(p.units) == 'table' and p.units) or {}
    local passives = (type(p.passives) == 'table' and p.passives) or {}
    local shop_level = (type(p.shop_level) == 'number' and p.shop_level) or 1
    local shop_xp = (type(p.shop_xp) == 'number' and p.shop_xp) or 0
    main:go_to('buy_screen', level, loop, units, passives, shop_level, shop_xp)
  elseif self.from then
    local prev = type(self.from) == 'table' and self.from.name or self.from
    if prev and type(prev) == 'string' and prev ~= '' then
      main:go_to(prev)
    else
      main:go_to('mainmenu')
    end
  else
    main:go_to('mainmenu')
  end
end

function WikiScreen:on_exit()
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
  if self.filter_buttons then
    for _, btn in ipairs(self.filter_buttons) do btn:die() end
  end
  if self.unit_cards then
    for _, card in ipairs(self.unit_cards) do card:die() end
  end
  if self.team_slots then
    for _, slot in ipairs(self.team_slots) do slot:die() end
  end
  if self.synergy_badges then
    for _, badge in ipairs(self.synergy_badges) do badge:die() end
  end
  if self.stat_gauges then
    for _, gauge in ipairs(self.stat_gauges) do gauge:die() end
  end
  if self.main then self.main:destroy() end
  if self.effects then self.effects:destroy() end
  if self.ui then self.ui:destroy() end
  self.main = nil
  self.effects = nil
  self.ui = nil
  self.filter_buttons = nil
  self.unit_cards = nil
  self.team_slots = nil
  self.synergy_badges = nil
  self.stat_gauges = nil
end

function WikiScreen:update(dt)
  self:update_game_object(dt)
  if self.main then self.main:update(dt) end
  if self.ui then self.ui:update(dt) end
  if self.effects then self.effects:update(dt) end

  if input.escape.pressed or input.w.pressed then
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    self:go_back()
  end
end

function WikiScreen:draw()
  graphics.rectangle(gw/2, gh/2, gw, gh, nil, nil, bg[-2])

  if self.title_text then
    self.title_text:draw(gw/2, 16)
  end

  -- Left Panel background (x: 10..300, y: 32..265 -> center 155, width 290, center 148, height 233)
  graphics.rectangle(155, 148, 290, 233, 4, 4, bg[-1])

  -- Right Panel background (x: 310..470, y: 32..265 -> center 390, width 160, center 148, height 233)
  graphics.rectangle(390, 148, 160, 233, 4, 4, bg[-1])

  self.main:draw()
  self.effects:draw()
  self:draw_right_panel_overlay()
  self.ui:draw()
end

function WikiScreen:build_filter_buttons()
  if self.filter_buttons then
    for _, btn in ipairs(self.filter_buttons) do btn:die() end
  end
  self.filter_buttons = {}

  local class_row1 = {'warrior', 'ranger', 'healer', 'conjurer', 'mage', 'nuker', 'rogue', 'enchanter'}
  local class_row2 = {'psyker', 'curser', 'forcer', 'swarmer', 'voider', 'sorcerer', 'mercenary', 'explorer'}

  local function layout_class_row(items, y_pos)
    local start_x = 44
    local gap = 31
    for i, c in ipairs(items) do
      local bx = start_x + (i - 1) * gap
      local btn = WikiClassFilterButton{
        group = self.ui,
        x = bx,
        y = y_pos,
        class = c,
        is_active_func = function()
          return self.selected_classes[c] == true
        end,
        action = function()
          ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
          if self.selected_classes[c] then
            self.selected_classes[c] = nil
          else
            self.selected_classes[c] = true
          end
          self:refresh_unit_cards()
        end
      }
      table.insert(self.filter_buttons, btn)
    end
  end

  layout_class_row(class_row1, 34)
  layout_class_row(class_row2, 52)

  local tier_list = {
    {label = 'ALL', tier = nil},
    {label = 'Tier 1', tier = 1},
    {label = 'Tier 2', tier = 2},
    {label = 'Tier 3', tier = 3},
    {label = 'Tier 4', tier = 4},
  }

  local function layout_tier_row(items, y_pos)
    local min_x = 30
    local max_x = 280
    local total_w = max_x - min_x
    local widths = {}
    local sum_w = 0
    for _, item in ipairs(items) do
      local tw = pixul_font:get_text_width(item.label)
      local bw = math.max(16, tw + 6)
      table.insert(widths, bw)
      sum_w = sum_w + bw
    end
    local gap = (#items > 1) and (total_w - sum_w) / (#items - 1) or 0
    local curr_x = min_x
    for i, item in ipairs(items) do
      local bw = widths[i]
      local bx = curr_x + bw / 2
      local btn = WikiFilterButton{
        group = self.ui,
        x = bx,
        y = y_pos,
        w = bw,
        h = 10,
        font = pixul_font,
        label = item.label,
        fg_color = 'yellow',
        is_active_func = function() return self.selected_tier == item.tier end,
        action = function()
          ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
          self.selected_tier = item.tier
          self:refresh_unit_cards()
        end
      }
      table.insert(self.filter_buttons, btn)
      curr_x = curr_x + bw + gap
    end
  end

  layout_tier_row(tier_list, 68)
end

function WikiScreen:init_stat_cache()
  self.unit_stat_cache = {}
  for _, unit_name in ipairs(self.all_units_sorted) do
    local base = { hp = 100, dmg = 10, aspd = 1, area = 1, def = 25, spd = 75 }
    local classes = character_classes[unit_name] or {}
    for _, c in ipairs(classes) do
      local m = class_stat_multipliers[c]
      if m then
        base.hp = base.hp * (m.hp or 1)
        base.dmg = base.dmg * (m.dmg or 1)
        base.aspd = base.aspd * (m.aspd or 1)
        base.area = base.area * ((m.area_dmg or 1) * (m.area_size or 1))
        base.def = base.def * (m.def or 1)
        base.spd = base.spd * (m.mvspd or 1)
      end
    end
    self.unit_stat_cache[unit_name] = base
  end
end

function WikiScreen:calculate_unit_tuple(character)
  local classes = character_classes[character] or {}
  local planned = main.planned_team or {}
  local units_per_class = get_number_of_units_per_class(planned)

  local p1 = 0
  local p2 = 0
  local p3 = 0
  local p4 = character_tiers[character] or 1

  for _, c in ipairs(classes) do
    local count = units_per_class[c] or 0
    local new_count = count + 1
    if class_set_numbers and class_set_numbers[c] then
      local i, j, k = class_set_numbers[c](planned)
      if (i and new_count == i) or (j and new_count == j) or (k and new_count == k) then
        p1 = p1 + 1
      end
    end
    if count > 0 then
      p2 = p2 + 1
    else
      p3 = p3 + 1
    end
  end

  return { p1 = p1, p2 = p2, p3 = p3, p4 = p4 }
end


function WikiScreen:get_filtered_units()
  local planned_set = {}
  if main and main.planned_team then
    for _, u in ipairs(main.planned_team) do
      if u and u.character then
        planned_set[u.character] = true
      end
    end
  end

  local visible_units = {}
  for _, unit_name in ipairs(self.all_units_sorted) do
    if not planned_set[unit_name] then
      local tier = character_tiers[unit_name] or 1
      local tier_match = (self.selected_tier == nil or tier == self.selected_tier)

      local class_match = false
      if next(self.selected_classes) == nil then
        class_match = true
      else
        local u_classes = character_classes[unit_name] or {}
        for _, cl in ipairs(u_classes) do
          if self.selected_classes[cl] then
            class_match = true
            break
          end
        end
      end

      if tier_match and class_match then
        table.insert(visible_units, unit_name)
      end
    end
  end

  return visible_units
end


function WikiScreen:refresh_unit_cards()
  if self.unit_cards then
    for _, card in ipairs(self.unit_cards) do card:die() end
  end
  self.unit_cards = {}

  local visible_units = self:get_filtered_units()

  table.sort(visible_units, function(a, b)
    local ta = self:calculate_unit_tuple(a)
    local tb = self:calculate_unit_tuple(b)
    if ta.p1 ~= tb.p1 then return ta.p1 > tb.p1 end
    if ta.p2 ~= tb.p2 then return ta.p2 > tb.p2 end
    if ta.p3 ~= tb.p3 then return ta.p3 > tb.p3 end
    if ta.p4 ~= tb.p4 then return ta.p4 > tb.p4 end
    return (character_names[a] or a) < (character_names[b] or b)
  end)

  local cards_per_row = 8
  local start_x = 64
  local start_y = 88
  local col_width = 26
  local row_height = 24

  for i, unit_name in ipairs(visible_units) do
    local col = (i - 1) % cards_per_row
    local row = math.floor((i - 1) / cards_per_row)
    local cx = start_x + col * col_width
    local cy = start_y + row * row_height

    local card = WikiUnitCard{
      group = self.ui,
      x = cx,
      y = cy,
      character = unit_name,
      parent = self
    }
    table.insert(self.unit_cards, card)
  end
end

function WikiScreen:calculate_unit_right_utility_score(character)
  local char_name = (type(character) == 'table' and character.character) and character.character or character
  if not char_name or type(char_name) ~= 'string' then return 0 end

  local planned = main.planned_team or {}
  local units_per_class = get_number_of_units_per_class(planned)
  local classes = character_classes[char_name] or {}
  local utility_score = 0

  for _, c in ipairs(classes) do
    local count = units_per_class[c] or 0
    if class_set_numbers and class_set_numbers[c] then
      local min_threshold = class_set_numbers[c](planned)
      if min_threshold and count >= min_threshold then
        utility_score = utility_score + count
      end
    end
  end

  return utility_score
end

function WikiScreen:sort_planned_team()
  if not main or not main.planned_team or #main.planned_team <= 1 then return end

  table.sort(main.planned_team, function(a, b)
    local char_a = (type(a) == 'table' and a.character) and a.character or a
    local char_b = (type(b) == 'table' and b.character) and b.character or b

    local score_a = self:calculate_unit_right_utility_score(char_a)
    local score_b = self:calculate_unit_right_utility_score(char_b)

    if score_a ~= score_b then
      return score_a > score_b
    end

    local tier_a = character_tiers[char_a] or 1
    local tier_b = character_tiers[char_b] or 1
    if tier_a ~= tier_b then
      return tier_a > tier_b
    end

    local name_a = character_names[char_a] or char_a
    local name_b = character_names[char_b] or char_b
    return name_a < name_b
  end)
end

function WikiScreen:refresh_right_panel()
  self:sort_planned_team()

  if self.team_slots then
    for _, slot in ipairs(self.team_slots) do slot:die() end
  end
  self.team_slots = {}

  if self.synergy_badges then
    for _, badge in ipairs(self.synergy_badges) do badge:die() end
  end
  self.synergy_badges = {}

  if self.stat_gauges then
    for _, gauge in ipairs(self.stat_gauges) do gauge:die() end
  end
  self.stat_gauges = {}

  local start_x = 325
  local col_w = 26
  local start_y = 52
  local row_h = 24

  for i = 1, 12 do
    local col = (i - 1) % 6
    local row = math.floor((i - 1) / 6)
    local sx = start_x + col * col_w
    local sy = start_y + row * row_h

    local slot = WikiTeamSlot{
      group = self.ui,
      x = sx,
      y = sy,
      index = i,
      parent = self
    }
    table.insert(self.team_slots, slot)
  end

  local gauges_def = {
    { key = 'hp', label = 'HP', color = red[0], color_name = 'red', y = 175 },
    { key = 'dmg', label = 'DMG', color = red[-2], color_name = 'red', y = 190 },
    { key = 'aspd', label = 'ASPD', color = yellow[0], color_name = 'yellow', y = 205 },
    { key = 'area', label = 'AREA', color = blue[0], color_name = 'blue', y = 220 },
    { key = 'def', label = 'DEF', color = purple[0], color_name = 'purple', y = 235 },
    { key = 'spd', label = 'SPD', color = green[0], color_name = 'green', y = 250 },
  }

  for _, gdef in ipairs(gauges_def) do
    local gauge = WikiStatGauge{
      group = self.ui,
      x = 385,
      y = gdef.y,
      stat_key = gdef.key,
      label = gdef.label,
      color = gdef.color,
      color_name = gdef.color_name,
      parent = self
    }
    table.insert(self.stat_gauges, gauge)
  end

  self:build_synergy_texts()
end

function WikiScreen:calculate_team_stat_benchmarks()
  if not self.unit_stat_cache then
    self:init_stat_cache()
  end

  local planned = main.planned_team or {}
  local K = #planned

  if K == 0 then
    local stats_data = {}
    local stat_keys = {'hp', 'dmg', 'aspd', 'area', 'def', 'spd'}
    for _, key in ipairs(stat_keys) do
      stats_data[key] = {
        current = 0,
        max_bench = 1,
        efficiency = 0,
        comment = "Empty Team"
      }
    end
    return stats_data
  end

  local units_per_class = get_number_of_units_per_class(planned)
  local active_classes = {}
  for _, c in ipairs(self.all_classes) do
    if (units_per_class[c] or 0) > 0 then
      table.insert(active_classes, c)
    end
  end

  local syn = { hp = 1, dmg = 1, aspd = 1, area = 1, def = 1, spd = 1 }
  for _, c in ipairs(active_classes) do
    if class_stat_multipliers[c] then
      local m = class_stat_multipliers[c]
      syn.hp = syn.hp * (m.hp or 1)
      syn.dmg = syn.dmg * (m.dmg or 1)
      syn.aspd = syn.aspd * (m.aspd or 1)
      syn.area = syn.area * ((m.area_dmg or 1) * (m.area_size or 1))
      syn.def = syn.def * (m.def or 1)
      syn.spd = syn.spd * (m.mvspd or 1)
    end
  end

  local curr = { hp = 0, dmg = 0, aspd = 0, area = 0, def = 0, spd = math.huge }
  for _, u in ipairs(planned) do
    local u_name = u.character
    local base = self.unit_stat_cache[u_name] or { hp = 100, dmg = 10, aspd = 1, area = 1, def = 25, spd = 75 }
    curr.hp = curr.hp + base.hp * syn.hp
    curr.dmg = curr.dmg + base.dmg * syn.dmg
    curr.aspd = curr.aspd + base.aspd * syn.aspd
    curr.area = curr.area + base.area * syn.area
    curr.def = curr.def + base.def * syn.def
    local u_spd = base.spd * syn.spd
    if u_spd < curr.spd then
      curr.spd = u_spd
    end
  end

  local stat_keys = {'hp', 'dmg', 'aspd', 'area', 'def', 'spd'}
  local min_bench = {}
  local max_bench = {}

  for _, key in ipairs(stat_keys) do
    if key == 'spd' then
      local speeds = {}
      for _, u_name in ipairs(self.all_units_sorted) do
        table.insert(speeds, (self.unit_stat_cache[u_name] and self.unit_stat_cache[u_name].spd) or 75)
      end
      table.sort(speeds, function(a, b) return a < b end)
      min_bench.spd = speeds[1] or 75

      table.sort(speeds, function(a, b) return a > b end)
      local spd_mults = {}
      for _, c in ipairs(self.all_classes) do
        if class_stat_multipliers[c] and (class_stat_multipliers[c].mvspd or 1) > 1 then
          table.insert(spd_mults, class_stat_multipliers[c].mvspd)
        end
      end
      table.sort(spd_mults, function(a, b) return a > b end)
      local max_syn_spd = 1
      for i = 1, math.min(K, #spd_mults) do
        max_syn_spd = max_syn_spd * spd_mults[i]
      end
      max_bench.spd = (speeds[math.min(K, #speeds)] or 75) * max_syn_spd
    else
      local stat_vals = {}
      for _, u_name in ipairs(self.all_units_sorted) do
        local val = (self.unit_stat_cache[u_name] and self.unit_stat_cache[u_name][key]) or 1
        table.insert(stat_vals, val)
      end
      table.sort(stat_vals, function(a, b) return a < b end)

      local min_sum = 0
      for i = 1, math.min(K, #stat_vals) do
        min_sum = min_sum + stat_vals[i]
      end
      min_bench[key] = min_sum

      table.sort(stat_vals, function(a, b) return a > b end)
      local max_sum = 0
      for i = 1, math.min(K, #stat_vals) do
        max_sum = max_sum + stat_vals[i]
      end

      local class_mults = {}
      for _, c in ipairs(self.all_classes) do
        if class_stat_multipliers[c] then
          local m = class_stat_multipliers[c]
          local mult_val = 1
          if key == 'area' then
            mult_val = (m.area_dmg or 1) * (m.area_size or 1)
          else
            mult_val = m[key] or 1
          end
          if mult_val > 1 then
            table.insert(class_mults, mult_val)
          end
        end
      end
      table.sort(class_mults, function(a, b) return a > b end)
      local max_syn = 1
      for i = 1, math.min(K, #class_mults) do
        max_syn = max_syn * class_mults[i]
      end

      max_bench[key] = max_sum * max_syn
    end
  end

  local stats_data = {}
  for _, key in ipairs(stat_keys) do
    local c_val = curr[key]
    local min_val = min_bench[key] or 0
    local max_val = max_bench[key] or 1

    local eff = 0
    if max_val <= min_val then
      eff = (c_val >= min_val) and 100 or 0
    else
      eff = math.floor(((c_val - min_val) / (max_val - min_val)) * 100)
      eff = math.min(100, math.max(0, eff))
    end

    local comment = "No Synergy Buff"
    if eff >= 100 then
      comment = "Optimal Synergy!"
    elseif eff >= 75 then
      comment = "Strong Synergy"
    elseif eff >= 40 then
      comment = "Moderate Synergy"
    elseif eff > 0 then
      comment = "Low Synergy"
    end

    stats_data[key] = {
      current = c_val,
      max_bench = max_val,
      efficiency = eff,
      comment = comment
    }
  end

  return stats_data
end

function WikiScreen:build_synergy_texts()
  if self.synergy_badges then
    for _, badge in ipairs(self.synergy_badges) do badge:die() end
  end
  self.synergy_badges = {}

  local planned = main.planned_team or {}
  local units_per_class = get_number_of_units_per_class(planned)
  local class_levels = get_class_levels(planned)

  local active_classes = {}
  for _, c in ipairs(self.all_classes) do
    if (units_per_class[c] or 0) > 0 then
      table.insert(active_classes, c)
    end
  end

  table.sort(active_classes, function(a, b)
    local la, lb = class_levels[a] or 0, class_levels[b] or 0
    if la ~= lb then return la > lb end
    return (units_per_class[a] or 0) > (units_per_class[b] or 0)
  end)

  for i, c in ipairs(active_classes) do
    local col = (i - 1) % 6
    local row = math.floor((i - 1) / 6)
    if row >= 2 then break end
    local bx = 335 + col * 22
    local by = 114 + row * 48

    local badge = WikiSynergyIconBadge{
      group = self.ui,
      x = bx,
      y = by,
      class = c,
      parent = self
    }
    table.insert(self.synergy_badges, badge)
  end
end

function WikiScreen:draw_right_panel_overlay()
end


WikiClassFilterButton = Object:extend()
WikiClassFilterButton:implement(GameObject)

function WikiClassFilterButton:init(args)
  self:init_game_object(args)
  self.class = args.class
  self.w = 16
  self.h = 16
  self.shape = Rectangle(self.x, self.y, self.w, self.h)
  self.interact_with_mouse = true
  self.is_active_func = args.is_active_func
  self.action = args.action
end

function WikiClassFilterButton:update(dt)
  self:update_game_object(dt)
  if self.selected and input.m1.pressed then
    input.m1.pressed = false
    if self.action then self:action() end
  end
end

function WikiClassFilterButton:draw()
  graphics.push(self.x, self.y, 0, self.spring.x, self.spring.y)
    local is_active = self.is_active_func and self.is_active_func()
    local bg_col = is_active and (class_colors[self.class] or fg[0]) or bg[3]
    graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, bg_col)
    if self.selected then
      graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, fg[0], 1)
    end
    local symbol_color = is_active and fg[-5] or (class_colors[self.class] or fg[0])
    if _G[self.class] and _G[self.class].draw then
      _G[self.class]:draw(self.x, self.y, 0, 0.3, 0.3, 0, 0, symbol_color)
    end
  graphics.pop()
end

function WikiClassFilterButton:on_mouse_enter()
  ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
  self.selected = true
  self.spring:pull(0.15, 200, 10)

  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end

  self.info_text = InfoText{group = main.current.ui}
  local color_str = class_color_strings[self.class] or 'fg'
  local cname = (self.class == 'conjurer' and 'Builder' or self.class:capitalize())
  self.info_text:activate({
    {text = '[' .. color_str .. ']' .. cname, font = pixul_font, alignment = 'center'},
  }, nil, nil, nil, nil, 16, 4, nil, 2)
  self.info_text.x, self.info_text.y = gw/2, gh/2
end

function WikiClassFilterButton:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiClassFilterButton:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end


WikiFilterButton = Object:extend()
WikiFilterButton:implement(GameObject)

function WikiFilterButton:init(args)
  self:init_game_object(args)
  self.w = args.w or 28
  self.h = args.h or 10
  self.font = args.font or pixul_font
  self.shape = Rectangle(self.x, self.y, self.w, self.h)
  self.interact_with_mouse = true
  self.text = Text({{text = '[' .. self.fg_color .. ']' .. self.label, font = self.font, alignment = 'center'}}, global_text_tags)
end

function WikiFilterButton:update(dt)
  self:update_game_object(dt)
  self.text:update(dt)
  if self.selected and input.m1.pressed then
    input.m1.pressed = false
    if self.action then self:action() end
  end
end

function WikiFilterButton:draw()
  graphics.push(self.x, self.y, 0, self.spring.x, self.spring.y)
    local is_active = self.is_active_func and self.is_active_func()
    local bg_col = self.selected and fg[0] or (is_active and fg[-2] or bg[3])
    graphics.rectangle(self.x, self.y, self.w, self.h, 2, 2, bg_col)
    self.text:draw(self.x, self.y + 1)
  graphics.pop()
end

function WikiFilterButton:on_mouse_enter()
  ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
  self.selected = true
  self.spring:pull(0.15, 200, 10)
end

function WikiFilterButton:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiFilterButton:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end


local function get_wiki_stats_string(character, level)
  local group = Group():set_as_physics_world(32, 0, 0, {'player', 'enemy', 'projectile', 'enemy_projectile'})
  local player = Player{group = group, leader = true, character = character, level = level or 1, follower_index = 1}
  player:update(0)
  return '[fg]Stats: [red]HP:' .. player.max_hp .. ' [red]DMG:' .. player.dmg .. ' [green]ASPD:' .. math.round(player.aspd_m, 2) .. 'x [blue]AREA:' .. math.round(player.area_dmg_m*player.area_size_m, 2) .. 'x [yellow]DEF:' .. math.round(player.def, 2) .. ' [green]SPD:' .. math.round(player.v, 2)
end

local function get_formatted_classes_string(character)
  local raw_classes = character_class_strings[character] or ''
  if raw_classes ~= '' then
    if raw_classes:find('^%[') then
      return raw_classes:gsub('^%[(.-)%]', '[%1](') .. '[fg])'
    else
      return '[fg](' .. raw_classes .. ')'
    end
  end
  return ''
end


WikiUnitCard = Object:extend()
WikiUnitCard:implement(GameObject)

function WikiUnitCard:init(args)
  self:init_game_object(args)
  self.character = args.character
  self.parent = args.parent
  self.w = 20
  self.h = 20
  self.shape = Rectangle(self.x, self.y, self.w, self.h)
  self.interact_with_mouse = true
end

function WikiUnitCard:update(dt)
  self:update_game_object(dt)

  if self.selected and input.m1.pressed then
    input.m1.pressed = false
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    main:toggle_planned_team(self.character)
    self.parent:refresh_right_panel()
    self.parent:refresh_unit_cards()
    self.spring:pull(0.2, 200, 10)
  end
end

function WikiUnitCard:draw()
  graphics.push(self.x, self.y, 0, self.spring.x, self.spring.y)
    local char_color = character_colors[self.character] or fg[0]

    graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, char_color)

    if self.selected then
      graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, fg[0], 1)
    end

    local num_str = tostring(character_tiers[self.character] or 1)
    graphics.print_centered(num_str, pixul_font, self.x, self.y + 1, 0, 1, 1, 0, 0, bg[0])
  graphics.pop()
end

function WikiUnitCard:on_mouse_enter()
  ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
  self.selected = true
  self.spring:pull(0.15, 200, 10)

  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end

  local tier = character_tiers[self.character] or 1

  self.info_text = InfoText{group = main.current.ui}
  local card_character = self.character
  self.info_text.draw = function(it)
    graphics.push(it.x + it.ox, it.y + it.oy, 0, it.sx*it.spring.x, it.sy*it.spring.x)
      graphics.rectangle(it.x + it.ox, it.y + it.oy, it.text.w + it.ow, it.text.h + it.oh, 3, 3, bg[-1])
      local border_col = character_colors[card_character] or fg[0]
      graphics.rectangle(it.x + it.ox, it.y + it.oy, it.text.w + it.ow, it.text.h + it.oh, 3, 3, border_col, 1)
      it.text:draw(it.x + it.ox + it.tox, it.y + it.oy + it.toy)
    graphics.pop()
  end

  self.info_text:activate({
    {text = '[' .. (character_color_strings[self.character] or 'fg') .. ']' .. (character_names[self.character] or self.character) .. ' [yellow](Tier ' .. tier .. ') ' .. get_formatted_classes_string(self.character), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = '', font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = get_wiki_stats_string(self.character, 1), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = '[fg]Spell: ' .. (character_descriptions[self.character] and character_descriptions[self.character](1) or ''), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = '[yellow]Lv.3 Passive: ' .. (character_effect_names[self.character] and ('[yellow]' .. character_effect_names[self.character] .. '[fg] - ') or '') .. (character_effect_descriptions[self.character] and character_effect_descriptions[self.character]() or ''), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
  }, nil, nil, nil, nil, 16, 4, nil, 2)
  self.info_text.x, self.info_text.y = gw/2, gh/2
end

function WikiUnitCard:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiUnitCard:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end


WikiTeamSlot = Object:extend()
WikiTeamSlot:implement(GameObject)

function WikiTeamSlot:init(args)
  self:init_game_object(args)
  self.index = args.index
  self.parent = args.parent
  self.w = 20
  self.h = 20
  self.shape = Rectangle(self.x, self.y, self.w, self.h)
  self.interact_with_mouse = true
end

function WikiTeamSlot:update(dt)
  self:update_game_object(dt)

  local planned = main.planned_team or {}
  local unit = planned[self.index]

  if self.selected and unit and unit.character then
    if input.m1.pressed or input.m2.pressed then
      local is_m1 = input.m1.pressed
      input.m1.pressed = false
      input.m2.pressed = false
      if is_m1 then
        ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      else
        ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      end
      if self.info_text then
        self.info_text:deactivate()
        self.info_text.dead = true
        self.info_text = nil
      end
      main:remove_from_planned_team(self.index)
      self.parent:refresh_right_panel()
      self.parent:refresh_unit_cards()
    end
  end
end

function WikiTeamSlot:draw()
  graphics.push(self.x, self.y, 0, self.spring.x, self.spring.y)
    local planned = main.planned_team or {}
    local unit = planned[self.index]
    if unit and unit.character then
      local bg_col = character_colors[unit.character] or fg[0]
      graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, bg_col)
      if self.selected then
        graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, fg[0], 1)
      end
      local tier_str = tostring(character_tiers[unit.character] or 1)
      graphics.print_centered(tier_str, pixul_font, self.x, self.y + 1, 0, 1, 1, 0, 0, bg[0])
    else
      local bg_col = bg[3]
      local border_col = bg[10]
      graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, bg_col)
      graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, border_col, 1)
      if self.selected then
        graphics.rectangle(self.x, self.y, self.w, self.h, 3, 3, fg[0], 1)
      end
    end
  graphics.pop()
end

function WikiTeamSlot:on_mouse_enter()
  local planned = main.planned_team or {}
  local unit = planned[self.index]
  if unit and unit.character then
    ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
    self.selected = true
    self.spring:pull(0.15, 200, 10)

    if self.info_text then
      self.info_text:deactivate()
      self.info_text.dead = true
      self.info_text = nil
    end

    local c = unit.character
    local tier = character_tiers[c] or 1

    self.info_text = InfoText{group = main.current.ui}
    self.info_text.draw = function(it)
      graphics.push(it.x + it.ox, it.y + it.oy, 0, it.sx*it.spring.x, it.sy*it.spring.x)
        graphics.rectangle(it.x + it.ox, it.y + it.oy, it.text.w + it.ow, it.text.h + it.oh, 3, 3, bg[-1])
        local border_col = character_colors[c] or fg[0]
        graphics.rectangle(it.x + it.ox, it.y + it.oy, it.text.w + it.ow, it.text.h + it.oh, 3, 3, border_col, 1)
        it.text:draw(it.x + it.ox + it.tox, it.y + it.oy + it.toy)
      graphics.pop()
    end

    self.info_text:activate({
      {text = '[' .. (character_color_strings[c] or 'fg') .. ']' .. (character_names[c] or c) .. ' [yellow](Tier ' .. tier .. ') ' .. get_formatted_classes_string(c), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
      {text = '', font = pixul_font, alignment = 'center', height_multiplier = 1.2},
      {text = get_wiki_stats_string(c, 1), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
      {text = '[fg]Spell: ' .. (character_descriptions[c] and character_descriptions[c](1) or ''), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
      {text = '[yellow]Lv.3 Passive: ' .. (character_effect_names[c] and ('[yellow]' .. character_effect_names[c] .. '[fg] - ') or '') .. (character_effect_descriptions[c] and character_effect_descriptions[c]() or ''), font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    }, nil, nil, nil, nil, 16, 4, nil, 2)
    self.info_text.x, self.info_text.y = gw/2, gh/2
  end
end

function WikiTeamSlot:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiTeamSlot:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end


WikiSynergyIconBadge = Object:extend()
WikiSynergyIconBadge:implement(GameObject)

function WikiSynergyIconBadge:init(args)
  self:init_game_object(args)
  self.class = args.class
  self.w = 16
  self.h = 42
  self.shape = Rectangle(self.x, self.y + 11, 20, 42)
  self.interact_with_mouse = true
  self.spring:pull(0.2, 200, 10)
end

function WikiSynergyIconBadge:update(dt)
  self:update_game_object(dt)
end

function WikiSynergyIconBadge:draw()
  graphics.push(self.x, self.y, 0, self.sx * self.spring.x, self.sy * self.spring.x)
    local units = main.planned_team or {}
    local i, j, k, n = class_set_numbers[self.class](units)

    -- Top box (16x24px)
    graphics.rectangle(self.x, self.y, 16, 24, 4, 4, self.selected and fg[0] or ((n >= i) and class_colors[self.class] or bg[3]))
    local symbol_color = self.selected and fg[-5] or ((n >= i) and _G[class_color_strings[self.class]][-5] or bg[10])
    if _G[self.class] and _G[self.class].draw then
      _G[self.class]:draw(self.x, self.y, 0, 0.3, 0.3, 0, 0, symbol_color)
    end

    -- Bottom box (16x16px at y + 26)
    graphics.rectangle(self.x, self.y + 26, 16, 16, 3, 3, self.selected and fg[0] or bg[3])

    if i == 1 then
      if self.selected then
        graphics.rectangle(self.x, self.y + 26, 3, 9, nil, nil, (n >= 1) and fg[-5] or fg[-10])
      else
        graphics.rectangle(self.x, self.y + 26, 3, 9, nil, nil, (n >= 1) and class_colors[self.class] or bg[10])
      end
    elseif i == 2 and not k then
      if self.selected then
        graphics.line(self.x - 3, self.y + 20, self.x - 3, self.y + 25, (n >= 1) and fg[-5] or fg[-10], 3)
        graphics.line(self.x - 3, self.y + 27, self.x - 3, self.y + 32, (n >= 2) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 4, self.y + 20, self.x + 4, self.y + 25, (n >= 3) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 4, self.y + 27, self.x + 4, self.y + 32, (n >= 4) and fg[-5] or fg[-10], 3)
      else
        graphics.line(self.x - 3, self.y + 20, self.x - 3, self.y + 25, (n >= 1) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x - 3, self.y + 27, self.x - 3, self.y + 32, (n >= 2) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 4, self.y + 20, self.x + 4, self.y + 25, (n >= 3) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 4, self.y + 27, self.x + 4, self.y + 32, (n >= 4) and class_colors[self.class] or bg[10], 3)
      end
    elseif i == 2 and k == 6 then
      if self.selected then
        graphics.line(self.x - 5, self.y + 21, self.x - 5, self.y + 24, (n >= 1) and fg[-5] or fg[-10], 3)
        graphics.line(self.x - 5, self.y + 28, self.x - 5, self.y + 31, (n >= 2) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 0, self.y + 21, self.x + 0, self.y + 24, (n >= 3) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 0, self.y + 28, self.x + 0, self.y + 31, (n >= 4) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 5, self.y + 21, self.x + 5, self.y + 24, (n >= 5) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 5, self.y + 28, self.x + 5, self.y + 31, (n >= 6) and fg[-5] or fg[-10], 3)
      else
        graphics.line(self.x - 5, self.y + 21, self.x - 5, self.y + 24, (n >= 1) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x - 5, self.y + 28, self.x - 5, self.y + 31, (n >= 2) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 0, self.y + 21, self.x + 0, self.y + 24, (n >= 3) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 0, self.y + 28, self.x + 0, self.y + 31, (n >= 4) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 5, self.y + 21, self.x + 5, self.y + 24, (n >= 5) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 5, self.y + 28, self.x + 5, self.y + 31, (n >= 6) and class_colors[self.class] or bg[10], 3)
      end
    elseif i == 3 then
      if self.selected then
        graphics.line(self.x - 3, self.y + 19, self.x - 3, self.y + 22, (n >= 1) and fg[-5] or fg[-10], 3)
        graphics.line(self.x - 3, self.y + 24, self.x - 3, self.y + 27, (n >= 2) and fg[-5] or fg[-10], 3)
        graphics.line(self.x - 3, self.y + 29, self.x - 3, self.y + 32, (n >= 3) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 4, self.y + 19, self.x + 4, self.y + 22, (n >= 4) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 4, self.y + 24, self.x + 4, self.y + 27, (n >= 5) and fg[-5] or fg[-10], 3)
        graphics.line(self.x + 4, self.y + 29, self.x + 4, self.y + 32, (n >= 6) and fg[-5] or fg[-10], 3)
      else
        graphics.line(self.x - 3, self.y + 19, self.x - 3, self.y + 22, (n >= 1) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x - 3, self.y + 24, self.x - 3, self.y + 27, (n >= 2) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x - 3, self.y + 29, self.x - 3, self.y + 32, (n >= 3) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 4, self.y + 19, self.x + 4, self.y + 22, (n >= 4) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 4, self.y + 24, self.x + 4, self.y + 27, (n >= 5) and class_colors[self.class] or bg[10], 3)
        graphics.line(self.x + 4, self.y + 29, self.x + 4, self.y + 32, (n >= 6) and class_colors[self.class] or bg[10], 3)
      end
    end
  graphics.pop()
end

function WikiSynergyIconBadge:on_mouse_enter()
  ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
  self.selected = true
  self.spring:pull(0.2, 200, 10)

  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end

  local units = main.planned_team or {}
  local i, j, k, owned = class_set_numbers[self.class](units)
  local active_lvl = (k and (owned >= k and 3)) or (owned >= j and 2) or (owned >= i and 1) or 0
  self.info_text = InfoText{group = main.current.ui}
  local color_str = class_color_strings[self.class] or 'fg'
  local cname = (self.class == 'conjurer' and 'Builder' or self.class:capitalize())
  local desc_str = class_descriptions[self.class] and class_descriptions[self.class](active_lvl) or ''

  self.info_text:activate({
    {text = '[' .. color_str .. ']' .. cname .. '[fg] - owned: [yellow]' .. owned .. ' [fg](Lvl ' .. active_lvl .. ')', font = pixul_font, alignment = 'center', height_multiplier = 1.25},
    {text = desc_str, font = pixul_font, alignment = 'center'},
  }, nil, nil, nil, nil, 16, 4, nil, 2)
  self.info_text.x, self.info_text.y = gw/2, gh/2 + 10
end

function WikiSynergyIconBadge:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiSynergyIconBadge:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end


WikiStatGauge = Object:extend()
WikiStatGauge:implement(GameObject)

function WikiStatGauge:init(args)
  self:init_game_object(args)
  self.stat_key = args.stat_key
  self.label = args.label or args.stat_key:upper()
  self.color = args.color or fg[0]
  self.color_name = args.color_name or 'fg'
  self.parent = args.parent
  self.w = 70
  self.h = 14
  self.shape = Rectangle(self.x, self.y, self.w, self.h)
  self.interact_with_mouse = true
end

function WikiStatGauge:update(dt)
  self:update_game_object(dt)
end

function WikiStatGauge:draw()
  graphics.push(self.x, self.y, 0, self.spring.x, self.spring.y)
    local benchmarks = self.parent and self.parent:calculate_team_stat_benchmarks()
    local data = benchmarks and benchmarks[self.stat_key] or { current = 1, max_bench = 1, efficiency = 0, comment = "No Synergy Buff" }

    local curr_val = data.current or 1
    local eff = data.efficiency or 0

    -- Left: Stat label
    local label_color = self.selected and fg[0] or self.color
    graphics.print(self.label, pixul_font, self.x - 48, self.y, 0, 1, 1, 0, pixul_font.h/2, label_color)

    -- Middle: 40px Progress bar
    graphics.rectangle(self.x + 5, self.y, 40, 4, 1, 1, bg[3])

    local fill_ratio = math.min(1, math.max(0, eff / 100))
    local fill_w = math.floor(40 * fill_ratio)
    if fill_w > 0 then
      local fill_x = (self.x + 5 - 20) + fill_w / 2
      graphics.rectangle(fill_x, self.y, fill_w, 4, 1, 1, self.color)
    end

    -- Right: Multiplier text / stat value
    local mult_str = (curr_val >= 10) and string.format('%.0f', curr_val) or string.format('%.1fx', curr_val)
    graphics.print(mult_str, pixul_font, self.x + 42, self.y, 0, 1, 1, 0, pixul_font.h/2, fg[0])
  graphics.pop()
end

function WikiStatGauge:on_mouse_enter()
  ui_hover1:play{pitch = random:float(1.3, 1.5), volume = 0.5}
  self.selected = true
  self.spring:pull(0.15, 200, 10)

  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end

  local benchmarks = self.parent and self.parent:calculate_team_stat_benchmarks()
  local data = benchmarks and benchmarks[self.stat_key] or { current = 0, max_bench = 1, efficiency = 0, comment = "No Synergy Buff" }

  self.info_text = InfoText{group = main.current.ui}
  local stat_title = self.label .. ' Synergy Performance'
  local curr_str = (data.current >= 10) and string.format('%.0f', data.current) or string.format('%.2fx', data.current)
  local max_str = (data.max_bench >= 10) and string.format('%.0f', data.max_bench) or string.format('%.2fx', data.max_bench)
  local eff_str = tostring(data.efficiency or 0) .. '%'
  local comment_str = data.comment or "No Synergy Buff"

  self.info_text:activate({
    {text = '[' .. self.color_name .. ']' .. stat_title, font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = '[fg]Current: [' .. self.color_name .. ']' .. curr_str .. ' [fg]| Max Benchmark: [yellow]' .. max_str, font = pixul_font, alignment = 'center', height_multiplier = 1.2},
    {text = '[fg]Team Efficiency: [yellow]' .. eff_str .. ' [fg](' .. comment_str .. ')', font = pixul_font, alignment = 'center'},
  }, nil, nil, nil, nil, 16, 4, nil, 2)
  self.info_text.x, self.info_text.y = gw/2, gh/2 + 10
end

function WikiStatGauge:on_mouse_exit()
  self.selected = false
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end

function WikiStatGauge:die()
  self.dead = true
  if self.info_text then
    self.info_text:deactivate()
    self.info_text.dead = true
    self.info_text = nil
  end
end
