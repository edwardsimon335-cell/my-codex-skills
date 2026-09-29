#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "json"

ROOT = File.expand_path(__dir__)
MANIFEST_PATH = File.join(ROOT, "prototype_manifest.json")
SCHEMA_PATH = File.join(ROOT, "prototype_manifest.schema.json")
PAGES_DIR = File.join(ROOT, "pages")
INDEX_PATH = File.join(ROOT, "hotspot-index.md")
PREVIEW_PATH = File.join(ROOT, "prototype-preview.html")
PREVIEW_TEMPLATE_PATH = File.join(ROOT, "prototype-preview.template.html")
README_PATH = File.join(ROOT, "README.md")
HASHES_PATH = File.join(ROOT, "artifact-hashes.json")

CHINESE_TYPE_LABELS = {
  "action_module" => "功能入口模块", "action_row" => "操作栏", "active_tab_indicator" => "当前分页指示",
  "analysis_field" => "分析结果字段", "anchored_popover" => "锚定浮层", "background_context" => "背景上下文",
  "body_text" => "正文说明", "bottom_sheet" => "底部面板", "brand_title" => "品牌标题",
  "camera_control_panel" => "拍摄控制区", "camera_toolbar" => "相机工具栏", "case_card" => "案例卡片",
  "color_palette" => "色板", "compact_empty_state" => "紧凑空状态", "compact_info_row" => "紧凑信息行",
  "compact_summary" => "紧凑摘要", "confirmation_dialog" => "确认对话框", "control" => "控制入口",
  "editorial_banner" => "内容宣传横幅", "exercise_module" => "练习模块", "fixed_header" => "固定标题栏",
  "horizontal_rail" => "横向选项栏", "image_annotation_map" => "图片标注区域", "image_card" => "图片卡片",
  "image_placeholder" => "图片占位", "information_dialog" => "信息对话框", "information_group" => "信息分组",
  "lesson_card" => "教学卡片", "live_preview" => "实时取景预览", "navigation_container" => "导航容器",
  "ordered_content" => "有序内容", "overlay_region" => "覆盖区域", "page_title" => "页面标题",
  "photo_thumbnail" => "照片缩略图", "section_heading" => "分区标题", "segmented_control" => "分段选择器",
  "selected_destination" => "已选导航项", "selected_tab" => "已选分页", "selection_group" => "选择组",
  "settings_group" => "设置分组", "settings_row" => "设置行", "slider" => "滑杆",
  "sticky_horizontal_rail" => "吸顶横向选项栏", "structured_content" => "结构化内容", "supporting_text" => "辅助文字",
  "task_banner" => "任务状态横幅", "thumbnail_row" => "缩略图行", "version" => "版本信息",
  "viewfinder_frame" => "取景框"
}.freeze

CHINESE_ACTION_LABELS = {
  "adjust_look_intensity" => "调整滤镜强度", "cancel_analysis_task" => "取消分析任务", "capture_photo" => "拍摄并保存照片",
  "close_ratio_picker" => "关闭画幅选择器", "delete_analysis" => "删除分析记录", "delete_photo" => "删除照片",
  "dismiss_dialog" => "关闭对话框", "dismiss_sheet" => "关闭底部面板", "dismiss_task_banner" => "关闭任务横幅",
  "export_photo" => "导出照片", "filter_cases" => "筛选案例", "focus_camera" => "相机对焦",
  "long_press_preview_tools" => "长按打开预览工具", "open_analysis_confirm" => "打开分析确认面板",
  "open_camera_with_look" => "携带当前滤镜进入拍摄", "open_dialog" => "打开说明对话框",
  "open_look_detail" => "打开滤镜详情", "open_look_drawer" => "打开滤镜选择区", "open_menu" => "打开更多菜单",
  "open_paywall_for_quota" => "因额度不足打开订阅方案", "open_ratio_picker" => "打开画幅选择器",
  "open_reference_capture" => "进入拍摄照片流程", "open_sheet" => "打开底部面板", "open_system_settings" => "打开系统设置",
  "pause_analysis_task" => "暂停分析任务", "pop_route" => "返回上一页", "push_route" => "进入目标页面",
  "replace_subpage" => "切换当前页内状态", "restore_purchase" => "恢复购买", "resume_analysis_task" => "继续分析任务",
  "retry_analysis_task" => "重试分析任务", "retry_camera_start" => "重试启动相机", "select_plan" => "选择订阅方案",
  "set_camera_ratio" => "设置相机画幅", "set_language" => "切换语言", "start_analysis" => "开始分析",
  "start_purchase" => "开始购买", "switch_camera_lens" => "切换前后镜头", "switch_primary_destination" => "切换一级页面",
  "toggle_camera_flash" => "切换闪光灯", "toggle_camera_grid" => "切换构图网格",
  "toggle_composition_overlay" => "显示或隐藏构图框线"
}.freeze

def esc(value)
  CGI.escapeHTML(value.to_s)
end

def number(value)
  return value.to_i.to_s if value.is_a?(Numeric) && value == value.to_i

  format("%.1f", value).sub(/\.0\z/, "")
end

def rect_text(rect)
  "[#{rect.map { |value| number(value) }.join(", ")}]"
end

def deep_copy(value)
  JSON.parse(JSON.generate(value))
end

def resolve_pointer(document, pointer)
  raise "Only local JSON pointers are supported: #{pointer}" unless pointer.start_with?("#/")

  pointer.delete_prefix("#/").split("/").reduce(document) do |cursor, raw_key|
    key = raw_key.gsub("~1", "/").gsub("~0", "~")
    raise "Unresolved JSON pointer #{pointer} at #{key}" unless cursor.is_a?(Hash) && cursor.key?(key)

    cursor.fetch(key)
  end
end

def json_type_matches?(value, expected)
  case expected
  when "object" then value.is_a?(Hash)
  when "array" then value.is_a?(Array)
  when "string" then value.is_a?(String)
  when "number" then value.is_a?(Numeric) && value.finite?
  when "integer" then value.is_a?(Integer)
  when "boolean" then value == true || value == false
  when "null" then value.nil?
  else false
  end
end

def validate_json_schema(value, schema, root_schema, path = "$")
  return validate_json_schema(value, resolve_pointer(root_schema, schema.fetch("$ref")), root_schema, path) if schema["$ref"]

  errors = []
  errors << "#{path}: expected const #{schema["const"].inspect}" if schema.key?("const") && value != schema["const"]
  errors << "#{path}: expected one of #{schema["enum"].inspect}" if schema["enum"] && !schema.fetch("enum").include?(value)

  if schema["type"] && !json_type_matches?(value, schema.fetch("type"))
    return errors << "#{path}: expected #{schema.fetch("type")}, got #{value.class}"
  end

  if value.is_a?(Hash)
    required = schema.fetch("required", [])
    required.each { |key| errors << "#{path}: missing required property #{key}" unless value.key?(key) }
    errors << "#{path}: expected at least #{schema.fetch("minProperties")} properties" if schema["minProperties"] && value.length < schema.fetch("minProperties")
    properties = schema.fetch("properties", {})
    properties.each do |key, child_schema|
      errors.concat(validate_json_schema(value.fetch(key), child_schema, root_schema, "#{path}.#{key}")) if value.key?(key)
    end
    extra_keys = value.keys - properties.keys
    additional = schema.fetch("additionalProperties", true)
    if additional == false
      extra_keys.each { |key| errors << "#{path}: additional property #{key} is not allowed" }
    elsif additional.is_a?(Hash)
      extra_keys.each do |key|
        errors.concat(validate_json_schema(value.fetch(key), additional, root_schema, "#{path}.#{key}"))
      end
    end
  elsif value.is_a?(Array)
    errors << "#{path}: expected at least #{schema.fetch("minItems")} items" if schema["minItems"] && value.length < schema.fetch("minItems")
    errors << "#{path}: expected at most #{schema.fetch("maxItems")} items" if schema["maxItems"] && value.length > schema.fetch("maxItems")
    prefix = schema.fetch("prefixItems", [])
    prefix.each_with_index do |child_schema, index|
      errors.concat(validate_json_schema(value[index], child_schema, root_schema, "#{path}[#{index}]")) if index < value.length
    end
    items = schema["items"]
    if items == false && value.length > prefix.length
      errors << "#{path}: items beyond index #{prefix.length - 1} are not allowed"
    elsif items.is_a?(Hash)
      start = prefix.empty? ? 0 : prefix.length
      value.each_with_index do |item, index|
        next if index < start

        errors.concat(validate_json_schema(item, items, root_schema, "#{path}[#{index}]"))
      end
    end
  elsif value.is_a?(String)
    errors << "#{path}: string shorter than #{schema.fetch("minLength")}" if schema["minLength"] && value.length < schema.fetch("minLength")
    errors << "#{path}: does not match #{schema.fetch("pattern")}" if schema["pattern"] && !Regexp.new(schema.fetch("pattern")).match?(value)
  elsif value.is_a?(Numeric)
    errors << "#{path}: must be >= #{schema.fetch("minimum")}" if schema["minimum"] && value < schema.fetch("minimum")
    errors << "#{path}: must be > #{schema.fetch("exclusiveMinimum")}" if schema["exclusiveMinimum"] && value <= schema.fetch("exclusiveMinimum")
  end

  errors
end

def expand_state(manifest, state)
  elements = []
  hotspots = []
  state.fetch("componentRefs", []).each do |pointer|
    component = deep_copy(resolve_pointer(manifest, pointer))
    elements.concat(component.fetch("elements", []))
    hotspots.concat(component.fetch("hotspots", []))
  end
  elements.concat(deep_copy(state.fetch("elements")))
  hotspots.concat(deep_copy(state.fetch("hotspots")))
  [elements, hotspots]
end

def round_up_to_grid(value, grid = 4)
  (value.to_f / grid).ceil * grid
end

def required_content_height(manifest, state, elements, hotspots)
  viewport_height = manifest.dig("coordinateSystem", "canvas", "height")
  scroll_items = (elements + hotspots).select { |item| item.fetch("coordinateSpace") == "scrollContent" }
  return viewport_height if scroll_items.empty?

  last_content_edge = scroll_items.map { |item| item.fetch("rect")[1] + item.fetch("rect")[3] }.max
  has_global_navigation = state.fetch("componentRefs", []).include?("#/shared/components/bottomNavigation")
  minimum_bottom_inset = if has_global_navigation
    118
  else
    manifest.dig("coordinateSystem", "safeArea", "bottom")
  end
  [viewport_height, round_up_to_grid(last_content_edge + minimum_bottom_inset)].max
end

def intersection_area(first_rect, second_rect)
  ax, ay, aw, ah = first_rect
  bx, by, bw, bh = second_rect
  width = [ax + aw, bx + bw].min - [ax, bx].max
  height = [ay + ah, by + bh].min - [ay, by].max
  return 0 if width <= 0 || height <= 0

  width * height
end

def overlap_allowed?(first, second)
  first.fetch("allowsOverlapWith", []).include?(second.fetch("id")) ||
    second.fetch("allowsOverlapWith", []).include?(first.fetch("id"))
end

def validate_manifest(manifest)
  errors = []
  errors << "schemaVersion must be 2" unless manifest["schemaVersion"] == 2
  errors << "prototype must remain a design spec" unless manifest["implementationStatus"] == "design_spec_not_implemented"
  errors << "baseline version must be 0.1.1+5" unless manifest["baselineAppVersion"] == "0.1.1+5"

  width = manifest.dig("coordinateSystem", "canvas", "width")
  viewport_height = manifest.dig("coordinateSystem", "canvas", "height")
  bottom_safe_edge = viewport_height - manifest.dig("coordinateSystem", "safeArea", "bottom")
  errors << "canvas width missing" unless width.is_a?(Numeric) && width.positive?
  errors << "canvas height missing" unless viewport_height.is_a?(Numeric) && viewport_height.positive?

  screens = manifest.fetch("screens")
  screen_ids = screens.map { |screen| screen.fetch("id") }
  duplicates = screen_ids.tally.select { |_id, count| count > 1 }.keys
  errors << "duplicate screen IDs: #{duplicates.join(", ")}" unless duplicates.empty?

  state_index = screens.to_h do |screen|
    [screen.fetch("id"), screen.fetch("states").map { |state| state.fetch("id") }]
  end

  screens.each do |screen|
    states = screen.fetch("states")
    state_ids = states.map { |state| state.fetch("id") }
    state_duplicates = state_ids.tally.select { |_id, count| count > 1 }.keys
    errors << "#{screen.fetch("id")}: duplicate states #{state_duplicates.join(", ")}" unless state_duplicates.empty?
    errors << "#{screen.fetch("id")}: defaultState does not resolve" unless state_ids.include?(screen.fetch("defaultState"))

    states.each do |state|
      prefix = "#{screen.fetch("id")}/#{state.fetch("id")}"
      begin
        state.fetch("componentRefs", []).each { |pointer| resolve_pointer(manifest, pointer) }
        elements, hotspots = expand_state(manifest, state)
      rescue StandardError => error
        errors << "#{prefix}: #{error.message}"
        next
      end

      element_duplicates = elements.map { |item| item.fetch("id") }.tally.select { |_id, count| count > 1 }.keys
      errors << "#{prefix}: duplicate element IDs #{element_duplicates.join(", ")}" unless element_duplicates.empty?
      hotspot_duplicates = hotspots.map { |item| item.fetch("id") }.tally.select { |_id, count| count > 1 }.keys
      errors << "#{prefix}: duplicate hotspot IDs #{hotspot_duplicates.join(", ")}" unless hotspot_duplicates.empty?

      max_height = state.fetch("contentHeight")
      required_height = required_content_height(manifest, state, elements, hotspots)
      if max_height != required_height
        errors << "#{prefix}: contentHeight #{number(max_height)} must equal normalized height #{number(required_height)}"
      end
      (elements + hotspots).each do |item|
        rect = item["rect"]
        unless rect.is_a?(Array) && rect.length == 4 && rect.all? { |value| value.is_a?(Numeric) && value.finite? }
          errors << "#{prefix}/#{item["id"]}: invalid rect"
          next
        end
        x, y, item_width, item_height = rect
        errors << "#{prefix}/#{item.fetch("id")}: non-positive rect" unless item_width.positive? && item_height.positive?
        errors << "#{prefix}/#{item.fetch("id")}: negative origin" if x.negative? || y.negative?
        unless item["clippedBy"]
          errors << "#{prefix}/#{item.fetch("id")}: exceeds canvas width" if x + item_width > width + 0.01
        end
        vertical_limit = item.fetch("coordinateSpace") == "scrollContent" ? max_height : viewport_height
        errors << "#{prefix}/#{item.fetch("id")}: exceeds #{item.fetch("coordinateSpace")} height" if y + item_height > vertical_limit + 0.01
      end

      hotspots.each do |hotspot|
        rect = hotspot.fetch("rect")
        if rect[2] < 48 || rect[3] < 48
          errors << "#{prefix}/#{hotspot.fetch("id")}: hotspot smaller than 48×48"
        end

        if %w[viewport overlay].include?(hotspot.fetch("coordinateSpace")) && rect[1] + rect[3] > bottom_safe_edge
          errors << "#{prefix}/#{hotspot.fetch("id")}: interactive foreground extends below bottom safe-area edge y=#{number(bottom_safe_edge)}"
        end

        target_screen = hotspot["targetScreen"]
        target_state = hotspot["targetState"]
        if target_screen
          errors << "#{prefix}/#{hotspot.fetch("id")}: target screen #{target_screen} missing" unless state_index.key?(target_screen)
          if target_state && state_index.key?(target_screen) && !state_index.fetch(target_screen).include?(target_state)
            errors << "#{prefix}/#{hotspot.fetch("id")}: target state #{target_screen}/#{target_state} missing"
          end
        elsif target_state
          errors << "#{prefix}/#{hotspot.fetch("id")}: targetState requires targetScreen"
        end
      end

      hotspots.combination(2) do |first, second|
        next if overlap_allowed?(first, second)
        next unless first.fetch("coordinateSpace") == second.fetch("coordinateSpace")

        area = intersection_area(first.fetch("rect"), second.fetch("rect"))
        errors << "#{prefix}: hotspots #{first.fetch("id")} and #{second.fetch("id")} overlap by #{number(area)}pt²" if area.positive?
      end

      if screen.fetch("id") == "camera"
        navigation_ids = %w[nav_home nav_explore nav_analysis nav_album nav_camera]
        camera_controls = hotspots.reject { |item| navigation_ids.include?(item.fetch("id")) }
        camera_controls.each do |hotspot|
          next unless hotspot.fetch("id").match?(/camera_(recent_photo|shutter|filter|filter_strength)/)

          bottom = hotspot.fetch("rect")[1] + hotspot.fetch("rect")[3]
          errors << "#{prefix}/#{hotspot.fetch("id")}: camera control extends below y=734" if bottom > 734
        end
        navigation = hotspots.select { |item| navigation_ids.include?(item.fetch("id")) }
        camera_controls.each do |control|
          navigation.each do |nav|
            next unless control.fetch("coordinateSpace") == nav.fetch("coordinateSpace")

            area = intersection_area(control.fetch("rect"), nav.fetch("rect"))
            errors << "#{prefix}: camera control #{control.fetch("id")} overlaps #{nav.fetch("id")}" if area.positive?
          end
        end
      end

      if screen.fetch("id") == "home" && %w[default_empty default_history].include?(state.fetch("id"))
        proactive_paywall = hotspots.any? do |hotspot|
          hotspot["targetScreen"] == "paywall" || hotspot.fetch("id").include?("upgrade")
        end
        errors << "#{prefix}: default home must not contain proactive paywall CTA" if proactive_paywall
      end

      if screen.fetch("id") == "home"
        primary = hotspots.find { |item| item.fetch("id") == "home_primary_import" }
        secondary = hotspots.find { |item| item.fetch("id") == "home_reference_capture" }
        errors << "#{prefix}: missing home dual-entry actions" unless primary && secondary
        if primary && secondary
          errors << "#{prefix}: primary entry must be 分析照片" unless primary["label"] == "分析照片" && primary["emphasis"] == "primary"
          errors << "#{prefix}: secondary entry must be 拍摄照片" unless secondary["label"] == "拍摄照片" && secondary["emphasis"] == "secondary"
          errors << "#{prefix}: home entries must be vertically stacked" unless primary.fetch("rect")[1] < secondary.fetch("rect")[1]
          errors << "#{prefix}: home entries must share full-width alignment" unless primary.fetch("rect").values_at(0, 2) == secondary.fetch("rect").values_at(0, 2)
        end
      end
    end
  end

  primary_headers = %w[homeHeader exploreHeader analysisHeader albumHeader]
  header_heights = primary_headers.map do |component_id|
    component = manifest.dig("shared", "components", component_id)
    header = component&.fetch("elements", [])&.find { |item| item.fetch("type") == "fixed_header" }
    errors << "#{component_id}: primary header missing" unless header
    header&.fetch("rect")&.[](3)
  end.compact
  errors << "primary headers must share one height" unless header_heights.uniq == [115]
  primary_headers.drop(1).each do |component_id|
    elements = manifest.dig("shared", "components", component_id, "elements") || []
    errors << "#{component_id}: non-home primary header must not contain brand elements" if elements.any? { |item| item.fetch("type") == "brand_title" }
  end

  camera = screens.find { |screen| screen.fetch("id") == "camera" }
  expected_ratios = {
    "live_4_3" => "4:3",
    "live_3_2" => "3:2",
    "live_1_1" => "1:1",
    "live_16_9" => "16:9"
  }
  expected_ratios.each do |state_id, label|
    state = camera.fetch("states").find { |item| item.fetch("id") == state_id }
    errors << "camera/#{state_id}: missing" unless state
    next unless state

    errors << "camera/#{state_id}: ratio label mismatch" unless state.dig("cameraRatio", "label") == label
    errors << "camera/#{state_id}: incorrect crop policy" unless state.dig("captureOutput", "cropPolicy") == "original_and_processed_cropped"
    errors << "camera/#{state_id}: must not preserve outside frame" unless state.dig("captureOutput", "preserveOutsideFrame") == false
  end

  analysis_detail = screens.find { |screen| screen.fetch("id") == "analysis_detail" }
  if analysis_detail.nil?
    errors << "analysis_detail screen missing"
  else
    expected_states = %w[overview composition camera_setup]
    actual_states = analysis_detail.fetch("states").map { |state| state.fetch("id") }
    errors << "analysis_detail: result states must be #{expected_states.join(", ")}" unless actual_states == expected_states
    analysis_detail.fetch("states").each do |state|
      prefix = "analysis_detail/#{state.fetch("id")}"
      elements, hotspots = expand_state(manifest, state)
      expected_fields = state.dig("fieldLayout", "fieldOrder") || []
      positioned_fields = expected_fields.filter_map { |id| elements.find { |item| item.fetch("id") == id } }
      errors << "#{prefix}: declared result fields missing" unless positioned_fields.length == expected_fields.length
      if positioned_fields.length == expected_fields.length
        y_positions = positioned_fields.map { |item| item.fetch("rect")[1] }
        errors << "#{prefix}: result fields must follow declared top-to-bottom order" unless y_positions == y_positions.sort
      end
      required_tabs = %w[analysis_detail_tab_overall analysis_detail_tab_composition analysis_detail_tab_camera]
      missing_tabs = required_tabs - hotspots.map { |item| item.fetch("id") }
      errors << "#{prefix}: missing result tabs #{missing_tabs.join(", ")}" unless missing_tabs.empty?
      action_row = elements.find { |item| item.fetch("id") == "analysis_detail_action_row" }
      tab_rail = elements.find { |item| item.fetch("id") == "analysis_detail_tabs" }
      if action_row && tab_rail
        action_bottom = action_row.fetch("rect")[1] + action_row.fetch("rect")[3]
        errors << "#{prefix}: result tabs must sit below photo actions" unless tab_rail.fetch("rect")[1] >= action_bottom + 8
      else
        errors << "#{prefix}: missing photo action row or result tab rail"
      end
      required_actions = %w[analysis_composition_overlay analysis_try_same_look]
      missing_actions = required_actions - hotspots.map { |item| item.fetch("id") }
      errors << "#{prefix}: missing photo actions #{missing_actions.join(", ")}" unless missing_actions.empty?
      selected = elements.find { |item| item.fetch("id") == "analysis_detail_tab_selected" }
      errors << "#{prefix}: selected tab indicator missing" unless selected
    end
  end

  all_elements = []
  all_hotspots = []
  manifest.dig("shared", "components").each_value do |component|
    all_elements.concat(component.fetch("elements", []))
    all_hotspots.concat(component.fetch("hotspots", []))
  end
  screens.each do |screen|
    screen.fetch("states").each do |state|
      all_elements.concat(state.fetch("elements"))
      all_hotspots.concat(state.fetch("hotspots"))
    end
  end
  missing_types = all_elements.map { |item| item.fetch("type") }.uniq - CHINESE_TYPE_LABELS.keys
  missing_actions = all_hotspots.map { |item| item.fetch("action") }.uniq - CHINESE_ACTION_LABELS.keys
  errors << "Chinese type labels missing: #{missing_types.join(", ")}" unless missing_types.empty?
  errors << "Chinese action labels missing: #{missing_actions.join(", ")}" unless missing_actions.empty?

  errors
end

def rect_svg(rect, klass, attributes = {})
  x, y, width, height = rect
  attrs = {
    "x" => number(x), "y" => number(y), "width" => number(width),
    "height" => number(height), "class" => klass
  }.merge(attributes)
  "<rect #{attrs.map { |key, value| %(#{key}=\"#{esc(value)}\") }.join(" ")} />"
end

def image_like?(type)
  type.match?(/image|photo|thumbnail|case_card|lesson_card|live_preview|viewfinder_frame/)
end

def element_svg(element)
  id = element.fetch("id")
  rect = element.fetch("rect")
  x, y, width, height = rect
  type = element.fetch("type")
  lines = []
  lines << %(<g data-element-id="#{esc(id)}" data-type="#{esc(type)}" data-rect="#{esc(rect_text(rect))}" data-coordinate-space="#{esc(element.fetch("coordinateSpace"))}" data-accuracy="#{esc(element.fetch("accuracy"))}">)
  lines << "  <title>#{esc(element.fetch("description"))}</title>"
  lines << "  #{rect_svg(rect, "element element--#{type}")}"
  if image_like?(type)
    lines << %(  <line x1="#{number(x)}" y1="#{number(y)}" x2="#{number(x + width)}" y2="#{number(y + height)}" class="placeholder-line" />)
    lines << %(  <line x1="#{number(x + width)}" y1="#{number(y)}" x2="#{number(x)}" y2="#{number(y + height)}" class="placeholder-line" />)
  end
  label_y = y + [[height / 2.0 + 3, 14].max, height - 4].min
  lines << %(  <text x="#{number(x + 5)}" y="#{number(label_y)}" class="element-label">#{esc(id)}</text>)
  lines << "</g>"
  lines.join("\n")
end

def hotspot_svg(hotspot, index)
  rect = hotspot.fetch("rect")
  x, y, width, height = rect
  circle_x = [[x + 12, 12].max, 381].min
  circle_y = [[y + 12, 12].max, 840].min
  target = [hotspot["targetScreen"], hotspot["targetState"]].compact.join("/")
  <<~SVG
    <g data-hotspot-id="#{esc(hotspot.fetch("id"))}" data-rect="#{esc(rect_text(rect))}" data-coordinate-space="#{esc(hotspot.fetch("coordinateSpace"))}" data-accuracy="#{esc(hotspot.fetch("accuracy"))}" data-action="#{esc(hotspot.fetch("action"))}" data-target="#{esc(target)}">
      <title>#{index + 1}. #{esc(hotspot.fetch("label"))} · #{esc(hotspot.fetch("action"))}#{target.empty? ? "" : " → #{esc(target)}"}</title>
      #{rect_svg(rect, "hotspot")}
      <circle cx="#{number(circle_x)}" cy="#{number(circle_y)}" r="9" class="hotspot-index" />
      <text x="#{number(circle_x)}" y="#{number(circle_y + 3.2)}" class="hotspot-number" text-anchor="middle">#{index + 1}</text>
    </g>
  SVG
end

def svg_document(manifest, screen, state, elements, hotspots)
  canvas_width = manifest.dig("coordinateSystem", "canvas", "width")
  viewport_height = manifest.dig("coordinateSystem", "canvas", "height")
  height = state.fetch("contentHeight")
  metadata = {
    prototypeVersion: manifest.fetch("prototypeVersion"),
    baselineAppVersion: manifest.fetch("baselineAppVersion"),
    implementationStatus: manifest.fetch("implementationStatus"),
    screen: screen.slice("id", "title", "routeKind"),
    state: state,
    coordinateSystem: manifest.fetch("coordinateSystem"),
    elements: elements,
    hotspots: hotspots
  }
  vertical_grid = (0..canvas_width.to_i).step(50).map { |x| %(<line x1="#{x}" y1="0" x2="#{x}" y2="#{height}" />) }.join("\n")
  horizontal_grid = (0..height.to_i).step(50).map { |y| %(<line x1="0" y1="#{y}" x2="#{canvas_width}" y2="#{y}" />) }.join("\n")
  scroll_region = state["scrollRegion"] ? rect_svg(state.fetch("scrollRegion"), "guide guide--scroll", { "data-region" => "scroll" }) : ""
  first_viewport_guide = if height > viewport_height
    %(<line x1="0" y1="#{viewport_height}" x2="#{canvas_width}" y2="#{viewport_height}" class="guide guide--viewport" /><text x="5" y="#{viewport_height - 5}" class="coordinate-label">first viewport #{viewport_height}</text>)
  else
    ""
  end
  scroll_items = (elements + hotspots).select { |item| item.fetch("coordinateSpace") == "scrollContent" }
  bottom_inset_guide = if height > viewport_height && !scroll_items.empty?
    last_content_edge = scroll_items.map { |item| item.fetch("rect")[1] + item.fetch("rect")[3] }.max
    has_global_navigation = state.fetch("componentRefs", []).include?("#/shared/components/bottomNavigation")
    minimum_bottom_inset = has_global_navigation ? 118 : manifest.dig("coordinateSystem", "safeArea", "bottom")
    inset_kind = has_global_navigation ? "global navigation clearance" : "iOS safe area"
    inset_height = height - last_content_edge
    %(<rect x="0" y="#{number(last_content_edge)}" width="#{canvas_width}" height="#{number(inset_height)}" class="guide guide--bottom-inset" /><text x="5" y="#{number(last_content_edge + 12)}" class="coordinate-label">reserved bottom inset #{number(inset_height)}pt · minimum #{number(minimum_bottom_inset)}pt · #{inset_kind}</text>)
  else
    ""
  end
  safe_top = manifest.dig("coordinateSystem", "safeArea", "top")
  safe_bottom = manifest.dig("coordinateSystem", "safeArea", "bottom")
  safe_bottom_edge = viewport_height - safe_bottom

  <<~SVG
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="#{canvas_width}" height="#{height}" viewBox="0 0 #{canvas_width} #{height}" role="img" aria-labelledby="title description" data-screen-id="#{esc(screen.fetch("id"))}" data-state-id="#{esc(state.fetch("id"))}" data-coordinate-unit="logical_pt">
      <title id="title">#{esc(state.fetch("title"))} · DECONSTRUCT V2 low-fidelity product prototype</title>
      <desc id="description">Design-spec coordinate prototype. Solid outlines are structural elements; dashed outlines are interactive hotspots. No production styling is represented.</desc>
      <metadata><![CDATA[#{JSON.pretty_generate(metadata)}]]></metadata>
      <style>
        .canvas { fill: #fff; }
        .grid line { stroke: #000; stroke-width: .35; opacity: .09; }
        .guide, .placeholder-line { fill: none; stroke: #000; stroke-width: 1; }
        .guide { stroke-dasharray: 5 4; opacity: .45; }
        .guide--viewport { stroke-width: 1.5; opacity: .72; }
        .guide--bottom-inset { stroke-dasharray: 2 3; opacity: .5; }
        .element { fill: #fff; stroke: #000; stroke-width: 1; }
        .element--fixed_header, .element--navigation_container, .element--camera_toolbar, .element--camera_control_panel, .element--bottom_sheet, .element--confirmation_dialog, .element--information_dialog, .element--anchored_popover { stroke-width: 1.25; }
        .element--body_text, .element--supporting_text, .element--section_heading, .element--page_title, .element--brand_title, .element--version { stroke-dasharray: 2 2; }
        .element--overlay_region, .element--background_context { stroke-dasharray: 7 4; opacity: .55; }
        .element--sticky_horizontal_rail { stroke-width: 1.5; }
        .element--selected_destination, .element--active_tab_indicator { fill: #e7e7e7; }
        .element--image_placeholder, .element--photo_thumbnail, .element--thumbnail_row, .element--case_card, .element--lesson_card, .element--live_preview, .element--viewfinder_frame, .element--image_card, .element--image_annotation_map { fill: #f4f4f4; }
        .hotspot { fill: #000; fill-opacity: .035; stroke: #000; stroke-width: 1.35; stroke-dasharray: 6 3; }
        .hotspot-index { fill: #fff; stroke: #000; stroke-width: 1; }
        text { fill: #000; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
        .element-label { font-size: 8px; }
        .coordinate-label { font-size: 7px; }
        .hotspot-number { font-size: 9px; font-weight: 600; }
      </style>
      <rect width="#{canvas_width}" height="#{height}" class="canvas" />
      <g class="grid" aria-hidden="true">#{vertical_grid}#{horizontal_grid}</g>
      <line x1="0" y1="#{safe_top}" x2="#{canvas_width}" y2="#{safe_top}" class="guide" />
      <line x1="0" y1="#{safe_bottom_edge}" x2="#{canvas_width}" y2="#{safe_bottom_edge}" class="guide" /><text x="5" y="#{viewport_height - 5}" class="coordinate-label">iOS bottom safe area #{safe_bottom}pt</text>
      #{scroll_region}
      #{first_viewport_guide}
      #{bottom_inset_guide}
      <g id="elements">#{elements.map { |item| element_svg(item) }.join("\n")}</g>
      <g id="hotspots">#{hotspots.each_with_index.map { |item, index| hotspot_svg(item, index) }.join("\n")}</g>
    </svg>
  SVG
end

def target_text(hotspot)
  return "—" unless hotspot["targetScreen"]

  [hotspot.fetch("targetScreen"), hotspot["targetState"]].compact.join("/")
end

def build_hotspot_index(manifest, expanded_states)
  lines = [
    "# DECONSTRUCT V2 热区索引",
    "",
    "坐标格式为 `[x, y, width, height]`，单位为逻辑点。V2 坐标均为 `design_spec`；它们描述待实现方案，不冒充生产实测值。",
    "",
    "| 原型文件 | 页面 / 状态 | # | 稳定 ID | 热区矩形 | 空间 | 角色 | Action | Target | 保留状态 |",
    "| --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |"
  ]
  expanded_states.each do |entry|
    entry.fetch(:hotspots).each_with_index do |hotspot, index|
      preserve = hotspot.fetch("preserve", []).join(", ")
      lines << "| [#{File.basename(entry.fetch(:state).fetch("prototypeFile"))}](#{entry.fetch(:state).fetch("prototypeFile")}) | #{entry.fetch(:screen).fetch("title")} / #{entry.fetch(:state).fetch("title")} | #{index + 1} | `#{hotspot.fetch("id")}` | `#{rect_text(hotspot.fetch("rect"))}` | `#{hotspot.fetch("coordinateSpace")}` | `#{hotspot.fetch("role")}` | `#{hotspot.fetch("action")}` | `#{target_text(hotspot)}` | #{preserve.empty? ? "—" : preserve} |"
    end
  end
  lines.join("\n") + "\n"
end

def build_readme(manifest, expanded_states)
  rows = manifest.fetch("screens").flat_map do |screen|
    screen.fetch("states").map do |state|
      entry = expanded_states.find { |item| item.fetch(:screen).fetch("id") == screen.fetch("id") && item.fetch(:state).fetch("id") == state.fetch("id") }
      "| #{screen.fetch("title")} | #{state.fetch("title")} | [SVG](#{state.fetch("prototypeFile")}) | #{entry.fetch(:hotspots).length} |"
    end
  end
  <<~MARKDOWN
    # DECONSTRUCT 产品原型 V2 中文审查副本

    本目录是基于 App `#{manifest.fetch("baselineAppVersion")}` 的未实现产品设计规格。它只表达结构、位置、状态、响应式规则和热区，不修改或代表 Flutter/原生相机的当前实现。

    ## 人工预览

    打开 [`prototype-preview.html`](prototype-preview.html) 可在“当前视图”和“全部页面”之间切换，也可进入浏览器全屏。每条标注均以中文展示元素标题、展示内容、展示条件、交互结果、状态集合和适配规则，并按需补充权限额度、异常处理、无障碍、数据埋点、内容规范与验收口径；鼠标悬浮、键盘聚焦或点击标注/画布元素时，两侧会同步高亮。

    ## 单一数据源

    - [`prototype_manifest.json`](prototype_manifest.json)：V2 坐标、状态、目标和行为的唯一数据源。
    - [`prototype_manifest.schema.json`](prototype_manifest.schema.json)：Schema V2 结构约束。
    - [`build_prototype.rb`](build_prototype.rb)：依次执行校验、SVG、热区索引、HTML、README 和哈希清单生成。
    - [`prototype-preview.template.html`](prototype-preview.template.html)：中文标注、多页面铺展、全屏与联动高亮的预览模板。
    - [`hotspot-index.md`](hotspot-index.md)：全部展开热区的人工核对表。
    - [`artifact-hashes.json`](artifact-hashes.json)：生成产物 SHA-256，便于确定性校验。

    不直接修改 `pages/*.svg`、`prototype-preview.html`、`hotspot-index.md` 或本 README；先改 manifest，再运行：

    ```bash
    ruby build_prototype.rb
    ```

    ## 基准和图例

    - 画布：`393 × 852pt`，顶部安全区 `59pt`，底部安全区 `34pt`。
    - `34pt` 是本原型参考设备竖屏值，不是所有 iOS 设备的硬编码常量；实现时读取系统 `safeAreaInsets.bottom`，无 Home Indicator 的设备或部分布局可能为 `0pt`。
    - 单屏内容统一使用 `852pt` 画布；只有确有首屏以下内容时才扩展完整滚动画布。滚动画布末端仅保留 `34pt` 系统安全区，或在全局导航存在时保留至少 `118pt` 的底栏避让。
    - `design_spec` 表示已确认的产品原型坐标，尚未从生产 Widget 实测。
    - 实线框：页面元素；虚线框：热区；交叉线：图片、案例、照片或相机预览占位。
    - 固定标题栏、吸顶筛选、底部导航和 Sheet 均在 manifest 中显式声明坐标空间。
    - 分析详情包含“整体分析、构图分析、相机参数”三个分页；分页位于照片直属操作区下方。
    - 正常首页没有主动升级 CTA；相机原图与成片均按所选画幅裁切。

    ## 页面和状态

    | 页面 | 状态 | 原始 SVG | 展开热区数 |
    | --- | --- | --- | ---: |
    #{rows.join("\n")}

    ## 响应式规则

    #{manifest.fetch("responsiveRules").map { |rule| "- `#{rule.fetch("id")}`：#{rule.fetch("rule")}" }.join("\n")}

    ## 边界

    - 本目录是 `docs/product-prototype-v2` 的独立中文审查副本；原目录不会被本副本的展示层改动影响。
    - 本阶段不修改 App 代码、接口、数据库、应用版本或图片资产。
    - 生产落地前仍需分别验证真机相机裁切、对焦坐标、前置镜像、横屏和性能。
  MARKDOWN
end

def build_preview(manifest)
  manifest_json = JSON.generate(manifest).gsub("</", "<\\/")
  <<~HTML
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>DECONSTRUCT V2 产品原型标注预览</title>
      <style>
        :root { color-scheme: light; --page:#f3f3f0; --paper:#fff; --ink:#171717; --muted:#686862; --line:#96968f; --border:#cacac3; --element:#484844; --hotspot:#77561f; --canvas-width:393px; }
        * { box-sizing:border-box; }
        body { margin:0; background:var(--page); color:var(--ink); font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
        button,select,input { font:inherit; }
        .toolbar { position:sticky; top:0; z-index:20; display:flex; flex-wrap:wrap; align-items:end; gap:12px 18px; padding:14px 20px; background:var(--paper); border-bottom:1px solid var(--border); }
        .heading { margin-right:auto; }
        h1 { margin:0; font-size:18px; font-weight:650; }
        .subtitle { margin-top:2px; color:var(--muted); font-size:12px; }
        .field { display:grid; gap:4px; color:var(--muted); font-size:12px; }
        select { min-width:280px; padding:8px 32px 8px 10px; border:1px solid var(--border); border-radius:4px; background:var(--paper); color:var(--ink); }
        .check { display:inline-flex; align-items:center; gap:6px; min-height:36px; white-space:nowrap; }
        .raw-link { display:inline-flex; align-items:center; min-height:36px; color:var(--ink); text-underline-offset:3px; }
        main { padding:20px; }
        .summary { display:flex; flex-wrap:wrap; gap:8px 18px; max-width:1500px; margin:0 auto 16px; color:var(--muted); }
        .summary strong { color:var(--ink); font-weight:600; }
        .stage { position:relative; display:grid; grid-template-columns:minmax(280px,1fr) var(--canvas-width) minmax(280px,1fr); gap:38px; align-items:start; max-width:1500px; margin:0 auto; min-height:852px; }
        .annotations { position:relative; min-width:0; z-index:3; }
        .prototype { position:relative; z-index:2; margin:20px 0 0; width:var(--canvas-width); }
        .prototype img { display:block; width:var(--canvas-width); height:auto; background:var(--paper); border:1px solid var(--ink); }
        .prototype figcaption { padding-top:8px; color:var(--muted); font-size:12px; text-align:center; }
        .leaders { position:absolute; inset:0; z-index:1; width:100%; height:100%; overflow:visible; pointer-events:none; }
        .leader { fill:none; stroke:var(--element); stroke-width:1; vector-effect:non-scaling-stroke; }
        .leader--hotspot { stroke:var(--hotspot); stroke-dasharray:5 4; }
        .leader-dot { fill:var(--paper); stroke:var(--element); stroke-width:1.5; vector-effect:non-scaling-stroke; }
        .leader-dot--hotspot { stroke:var(--hotspot); }
        .callout { position:absolute; width:min(100%,350px); padding:8px 10px; background:var(--paper); border:1px solid var(--border); }
        .annotations--left .callout { right:0; }
        .annotations--right .callout { left:0; }
        .callout--hotspot { border-left:3px dashed var(--hotspot); }
        .callout--element { border-left:3px solid var(--element); }
        .callout__top { display:flex; align-items:baseline; gap:7px; }
        .kind { flex:0 0 auto; color:var(--muted); font-size:11px; letter-spacing:.04em; }
        .id { min-width:0; overflow-wrap:anywhere; font:600 12px/1.35 ui-monospace,SFMono-Regular,Menlo,monospace; }
        .rect { margin-top:3px; color:var(--muted); font:11px/1.35 ui-monospace,SFMono-Regular,Menlo,monospace; }
        .description { margin-top:4px; font-size:12px; }
        .legend { max-width:1500px; margin:18px auto 0; padding-top:12px; border-top:1px solid var(--border); color:var(--muted); font-size:12px; }
        .legend span { display:inline-block; margin-right:18px; }
        .legend-element::before,.legend-hotspot::before { content:""; display:inline-block; width:24px; margin-right:6px; vertical-align:3px; border-top:1px solid var(--element); }
        .legend-hotspot::before { border-top:1px dashed var(--hotspot); }
        .empty { position:absolute; top:20px; padding:10px; color:var(--muted); border:1px dashed var(--border); }
        @media (max-width:1100px) {
          .stage { display:flex; flex-direction:column; height:auto !important; }
          .prototype { order:1; margin:20px auto; }
          .annotations { position:static; display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; margin-top:8px; height:auto !important; }
          .annotations--left { order:2; }
          .annotations--right { order:3; }
          .callout { position:static; width:100%; }
          .leaders { display:none; }
        }
        @media (max-width:620px) {
          main,.toolbar { padding:12px; }
          .field,select { width:100%; }
          .stage { width:100%; align-items:stretch; }
          .prototype { align-self:center; width:100%; max-width:var(--canvas-width); min-width:0; }
          .prototype img { width:100%; max-width:100%; }
          .annotations { grid-template-columns:1fr; }
        }
      </style>
    </head>
    <body>
      <header class="toolbar">
        <div class="heading">
          <h1>DECONSTRUCT V2 产品原型标注预览</h1>
          <div class="subtitle">基于 0.1.1+5 · design spec · 无成品 UI 渲染</div>
        </div>
        <label class="field">页面 / 状态
          <select id="screen-select" aria-label="选择页面和状态"></select>
        </label>
        <label class="check"><input id="show-elements" type="checkbox" checked> 元素说明</label>
        <label class="check"><input id="show-hotspots" type="checkbox" checked> 热区说明</label>
        <a id="raw-link" class="raw-link" href="#" target="_blank" rel="noopener">打开原始 SVG</a>
      </header>
      <main>
        <div id="summary" class="summary" aria-live="polite"></div>
        <section id="stage" class="stage" aria-label="带双侧标注的页面原型">
          <div id="left-annotations" class="annotations annotations--left"></div>
          <figure class="prototype">
            <img id="prototype-image" alt="">
            <figcaption id="prototype-caption"></figcaption>
          </figure>
          <div id="right-annotations" class="annotations annotations--right"></div>
          <svg id="leaders" class="leaders" aria-hidden="true"></svg>
        </section>
        <div class="legend">
          <span class="legend-element">实线：元素说明</span>
          <span class="legend-hotspot">虚线：交互热区</span>
          <span>坐标：[x, y, width, height] logical pt</span>
          <span>页面选择只切换静态审查状态</span>
        </div>
      </main>
      <script id="prototype-manifest" type="application/json">#{manifest_json}</script>
      <script>
        (() => {
          const manifest = JSON.parse(document.getElementById('prototype-manifest').textContent);
          const select = document.getElementById('screen-select');
          const showElements = document.getElementById('show-elements');
          const showHotspots = document.getElementById('show-hotspots');
          const rawLink = document.getElementById('raw-link');
          const stage = document.getElementById('stage');
          const image = document.getElementById('prototype-image');
          const caption = document.getElementById('prototype-caption');
          const summary = document.getElementById('summary');
          const left = document.getElementById('left-annotations');
          const right = document.getElementById('right-annotations');
          const leaders = document.getElementById('leaders');
          const screens = manifest.screens.flatMap(screen => screen.states.map(state => ({ screen, state, key:`${screen.id}/${state.id}` })));
          document.documentElement.style.setProperty('--canvas-width', `${manifest.coordinateSystem.canvas.width}px`);

          function resolvePointer(pointer) {
            return pointer.slice(2).split('/').reduce((value, rawKey) => value[rawKey.replaceAll('~1','/').replaceAll('~0','~')], manifest);
          }
          function expanded(screen) {
            const elements=[]; const hotspots=[];
            (screen.state.componentRefs || []).forEach(pointer => {
              const component=resolvePointer(pointer);
              elements.push(...(component.elements || [])); hotspots.push(...(component.hotspots || []));
            });
            elements.push(...screen.state.elements); hotspots.push(...screen.state.hotspots);
            return { elements, hotspots };
          }
          function escapeHtml(value) {
            return String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'})[character]);
          }
          function rectText(rect) { return `[${rect.join(', ')}]`; }
          function currentScreen() { return screens.find(screen => screen.key === select.value) || screens[0]; }
          function targetText(item) { return item.targetScreen ? `${item.targetScreen}${item.targetState ? `/${item.targetState}` : ''}` : '—'; }
          function makeItems(screen) {
            const data=expanded(screen); const items=[];
            if (showElements.checked) data.elements.forEach((item,index) => items.push({kind:'element',order:index+1,id:item.id,rect:item.rect,accuracy:item.accuracy,space:item.coordinateSpace,description:item.description}));
            if (showHotspots.checked) data.hotspots.forEach((item,index) => items.push({kind:'hotspot',order:index+1,id:item.id,rect:item.rect,accuracy:item.accuracy,space:item.coordinateSpace,description:`${item.label} · ${item.action} · target ${targetText(item)}`}));
            const sideCount={left:0,right:0};
            items.forEach(item => {
              const center=item.rect[0]+item.rect[2]/2;
              const spansCenter=item.rect[0] < 140 && item.rect[0]+item.rect[2] > 253;
              item.side=spansCenter || Math.abs(center-manifest.coordinateSystem.canvas.width/2)<36 ? (sideCount.left<=sideCount.right?'left':'right') : (center<manifest.coordinateSystem.canvas.width/2?'left':'right');
              sideCount[item.side]+=1;
            });
            return items;
          }
          function calloutMarkup(item) {
            const prefix=item.kind==='hotspot'?`H${String(item.order).padStart(2,'0')}`:`E${String(item.order).padStart(2,'0')}`;
            return `<div class="callout__top"><span class="kind">${prefix}</span><span class="id">${escapeHtml(item.id)}</span></div><div class="rect">${escapeHtml(rectText(item.rect))} · ${escapeHtml(item.space)} · ${escapeHtml(item.accuracy)}</div><div class="description">${escapeHtml(item.description)}</div>`;
          }
          function createCallouts(items) {
            left.replaceChildren(); right.replaceChildren();
            items.forEach(item => {
              const node=document.createElement('article'); node.className=`callout callout--${item.kind}`; node.dataset.kind=item.kind; node.dataset.side=item.side; node.dataset.rect=item.rect.join(','); node.innerHTML=calloutMarkup(item); (item.side==='left'?left:right).append(node);
            });
          }
          function layoutSide(container, phoneTop, scale, stageHeight) {
            const nodes=[...container.querySelectorAll('.callout')];
            if (!nodes.length) { container.innerHTML='<div class="empty">当前筛选没有标注</div>'; return; }
            const gap=8;
            const entries=nodes.map(node => { const rect=node.dataset.rect.split(',').map(Number); const height=node.offsetHeight; return {node,rect,height,desired:phoneTop+(rect[1]+rect[3]/2)*scale-height/2}; }).sort((a,b)=>a.desired-b.desired);
            let cursor=10; entries.forEach(entry=>{entry.top=Math.max(cursor,entry.desired);cursor=entry.top+entry.height+gap;});
            let nextTop=stageHeight-10; for(let index=entries.length-1;index>=0;index-=1){const entry=entries[index];entry.top=Math.min(entry.top,nextTop-entry.height);nextTop=entry.top-gap;}
            if(entries[0].top<10){const shift=10-entries[0].top;entries.forEach(entry=>{entry.top+=shift;});}
            entries.forEach(entry=>{entry.node.style.top=`${entry.top}px`;});
          }
          function requiredHeight(container) { return [...container.querySelectorAll('.callout')].reduce((total,node)=>total+node.offsetHeight+8,20); }
          function svgNode(name,attributes) { const node=document.createElementNS('http://www.w3.org/2000/svg',name); Object.entries(attributes).forEach(([key,value])=>node.setAttribute(key,value)); return node; }
          function drawLeaders() {
            leaders.replaceChildren(); if(matchMedia('(max-width:1100px)').matches) return;
            const stageRect=stage.getBoundingClientRect(); const imageRect=image.getBoundingClientRect(); const scale=imageRect.width/manifest.coordinateSystem.canvas.width;
            leaders.setAttribute('viewBox',`0 0 ${stage.clientWidth} ${stage.clientHeight}`); leaders.setAttribute('width',stage.clientWidth); leaders.setAttribute('height',stage.clientHeight);
            document.querySelectorAll('.callout[data-rect]').forEach(node=>{
              const rect=node.dataset.rect.split(',').map(Number); const calloutRect=node.getBoundingClientRect(); const side=node.dataset.side;
              const startX=side==='left'?calloutRect.right-stageRect.left:calloutRect.left-stageRect.left; const startY=calloutRect.top-stageRect.top+calloutRect.height/2;
              const targetX=imageRect.left-stageRect.left+(side==='left'?rect[0]:rect[0]+rect[2])*scale; const targetY=imageRect.top-stageRect.top+(rect[1]+rect[3]/2)*scale;
              const elbowX=side==='left'?imageRect.left-stageRect.left-16:imageRect.right-stageRect.left+16; const hot=node.dataset.kind==='hotspot';
              leaders.append(svgNode('polyline',{points:`${startX},${startY} ${elbowX},${startY} ${elbowX},${targetY} ${targetX},${targetY}`,class:`leader${hot?' leader--hotspot':''}`}));
              leaders.append(svgNode('circle',{cx:targetX,cy:targetY,r:3,class:`leader-dot${hot?' leader-dot--hotspot':''}`}));
            });
          }
          function layout() {
            if(matchMedia('(max-width:1100px)').matches){stage.style.height='auto';left.style.height='auto';right.style.height='auto';leaders.replaceChildren();return;}
            const scale=image.clientWidth/manifest.coordinateSystem.canvas.width; const phoneHeight=image.clientHeight+image.offsetTop+40; const stageHeight=Math.max(phoneHeight,requiredHeight(left),requiredHeight(right),852);
            stage.style.height=`${stageHeight}px`; left.style.height=`${stageHeight}px`; right.style.height=`${stageHeight}px`; layoutSide(left,image.offsetTop,scale,stageHeight); layoutSide(right,image.offsetTop,scale,stageHeight); drawLeaders();
          }
          function render() {
            const screen=currentScreen(); const data=expanded(screen); const items=makeItems(screen);
            const canvasKind=screen.state.contentHeight===manifest.coordinateSystem.canvas.height?'single viewport':'full scroll canvas';
            image.src=screen.state.prototypeFile; image.alt=`${screen.state.title} 低保真坐标原型`; caption.textContent=`${screen.state.title} · ${screen.state.accuracy} · ${screen.state.contentHeight}pt ${canvasKind}`; rawLink.href=screen.state.prototypeFile;
            summary.innerHTML=`<span><strong>${escapeHtml(screen.screen.title)}</strong></span><span>状态：${escapeHtml(screen.state.id)}</span><span>元素：${data.elements.length}</span><span>热区：${data.hotspots.length}</span><span>坐标精度：${escapeHtml(screen.state.accuracy)}</span>`;
            createCallouts(items); image.onload=()=>requestAnimationFrame(layout); requestAnimationFrame(layout);
          }
          screens.forEach(screen=>{const option=document.createElement('option');option.value=screen.key;option.textContent=screen.state.title;select.append(option);});
          select.value='home/default_history'; select.addEventListener('change',render); showElements.addEventListener('change',render); showHotspots.addEventListener('change',render); addEventListener('resize',()=>requestAnimationFrame(layout)); render();
        })();
      </script>
    </body>
    </html>
  HTML
end

def build_review_preview(manifest)
  template = File.read(PREVIEW_TEMPLATE_PATH)
  manifest_json = JSON.generate(manifest).gsub("</", "<\\/")
  type_labels = JSON.generate(CHINESE_TYPE_LABELS).gsub("</", "<\\/")
  action_labels = JSON.generate(CHINESE_ACTION_LABELS).gsub("</", "<\\/")
  template
    .gsub("__PRODUCT_NAME__", CGI.escapeHTML(manifest.fetch("product")))
    .sub("__PROTOTYPE_MANIFEST__", manifest_json)
    .sub("__CHINESE_TYPE_LABELS__", type_labels)
    .sub("__CHINESE_ACTION_LABELS__", action_labels)
end

manifest = JSON.parse(File.read(MANIFEST_PATH))
schema = JSON.parse(File.read(SCHEMA_PATH))
errors = validate_json_schema(manifest, schema, schema) + validate_manifest(manifest)
unless errors.empty?
  warn "Prototype validation failed (#{errors.length} errors):"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

FileUtils.mkdir_p(PAGES_DIR)
expanded_states = []
manifest.fetch("screens").each do |screen|
  screen.fetch("states").each do |state|
    elements, hotspots = expand_state(manifest, state)
    output_path = File.join(ROOT, state.fetch("prototypeFile"))
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, svg_document(manifest, screen, state, elements, hotspots))
    expanded_states << { screen: screen, state: state, elements: elements, hotspots: hotspots }
  end
end

expected_page_files = expanded_states.map { |entry| File.join(ROOT, entry.fetch(:state).fetch("prototypeFile")) }
Dir.glob(File.join(PAGES_DIR, "*.svg")).each do |path|
  File.delete(path) unless expected_page_files.include?(path)
end

File.write(INDEX_PATH, build_hotspot_index(manifest, expanded_states))
File.write(PREVIEW_PATH, build_review_preview(manifest))
File.write(README_PATH, build_readme(manifest, expanded_states))

generated_paths = [README_PATH, INDEX_PATH, PREVIEW_PATH, *expected_page_files].sort
hashes = generated_paths.to_h do |path|
  [path.delete_prefix("#{ROOT}/"), Digest::SHA256.file(path).hexdigest]
end
File.write(HASHES_PATH, JSON.pretty_generate({ "algorithm" => "SHA-256", "files" => hashes }) + "\n")

puts "Validated schema V#{manifest.fetch("schemaVersion")} and generated #{expanded_states.length} states, #{expanded_states.sum { |entry| entry.fetch(:hotspots).length }} expanded hotspots."
