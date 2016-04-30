#!/usr/bin/env luajit

local Mrg = require('mrg')
local Zn = require('zn');

local zn=Zn.new()
local mrg=Mrg.new(640,480);

local item_no = 0;

local list_mode = false;

local css = [[
  .body { margin: 1em; margin-top:0;}
  .title {font-size: 30px; width: 100%; color: black;
    margin-bottom: 1em;
  }
  .item {font-size: 20px; width: 100%; color: black; border: 1px solid transparent; 
     margin-top: 0.5em;
  
  }
  .children { color : red }
  .selected { border: 1px solid blue; }
  .parents {font-size: 10px; display: block-inline; padding-right: 4em; }
]]

title="todo"
if (#arg >= 1) then title = arg[1] end

id=zn:string(title)

mrg:css_set(css)

local scroll_x = 0
local scroll_y = 0

local history = {}
local historic_item_no = {}

function cgo(target)
  table.insert(history, id)
  table.insert(historic_item_no, item_no)

  id = target
  item_no=0
  mrg:queue_draw(nil)
end

function cback()
  if table.getn(history) > 0 then
    id = table.remove(history)
    item_no= table.remove(historic_item_no)
    mrg:queue_draw(nil)
  end
end

function view_list (mrg)
  local cr = mrg:cr()

  cr:rectangle(0,0,mrg:width(),mrg:height())
  mrg:listen(Mrg.DRAG_MOTION + Mrg.DRAG_PRESS,
    function(event)
      if event.type == Mrg.DRAG_PRESS then
      elseif event.type == Mrg.DRAG_MOTION then
        scroll_y = scroll_y + event.delta_y
        --scroll_x = scroll_x + event.delta_x
      end
      mrg:queue_draw(nil)
      event:stop_propagate()
      return 0
    end)
  cr:new_path()
  cr:translate(scroll_x, scroll_y)

  mrg:start("div.body")
  mrg:start("div.title")

  local mimetype = zn:get_mime_type(id)

  if mimetype == "text/plain" then
  if item_no == -1 then
  mrg:edit_start(
       function(new_text)
         cgo(zn:string(new_text))
         item_no=-1
       end)
    mrg:print(zn:deref(id))
    zn:unref(id)
  mrg:edit_end()
  else
    mrg:text_listen(Mrg.TAP, function() 
      item_no = -1
      mrg:queue_draw(nil)
    end)
    mrg:print(zn:deref(id))
    zn:unref(id)
  end
  else
    mrg:print("[" .. mimetype .. "]")
  end

  mrg:close()

  for i = 0, zn:count_parents(id)-1 do
    local parent = zn:get_parents(id)[i]

    mrg:start("div.item.parents")
    mrg:text_listen(Mrg.TAP, function()
       cgo(parent)
    end)
    mrg:print(zn:deref(parent))
    mrg:text_listen_done()
    mrg:close()
  end

  for i = 0, zn:count_children(id)-1 do
    local child = zn:list_children(id)[i]
    if (zn:count_children(child) > 0) then
      mrg:text_listen(Mrg.TAP, function()
         cgo(child)
      end)
      end

      if zn:count_children(child) > 0 then
        if i == item_no then
          mrg:start("div.item.children.selected")
        else
          mrg:start("div.item.children")
        end
      else
        if i == item_no then
          mrg:start("div.item.selected")
        else
          mrg:start("div.item")
        end
      end

      local mimetype = zn:get_mime_type(child)

      if mimetype == 'text/plain' then
        if i == item_no and list_mode then
          mrg:edit_start(
            function(new_text)
              zn:replace_child(id, item_no, zn:string(new_text))
              mrg:queue_draw(nil)
            end)
          mrg:print(zn:deref(child))
          mrg:edit_end()
        else
          mrg:print(zn:deref(child))
        end
      elseif mimetype == 'image/jpeg' or
             mimetype == 'image/png' then
        local title = zn:get_key(child, zn:string("dc:title"))
        if title then
          mrg:print(zn:deref(title))
        else
          mrg:print(mimetype)
        end
      else
        mrg:print(mimetype)
      end

      zn:unref(child)
      mrg:close()
    if (zn:count_children(child) > 0) then
      mrg:text_listen_done()
    end
  end
  mrg:close()

  mrg:add_binding("down", NULL, NULL,
    function (event)
      item_no = item_no + 1
      if item_no > zn:count_children(id) - 1 then item_no = zn:count_children(id) - 1 end
      mrg:set_cursor_pos(0)
      mrg:queue_draw(nil)
      event:stop_propagate()
    end)

  mrg:add_binding("up", NULL, NULL,
    function (event)
      item_no = item_no - 1
      if item_no < -1 then item_no = -1 end
      mrg:set_cursor_pos(0)
      mrg:queue_draw(nil)
      event:stop_propagate()
    end)

  mrg:add_binding("tab", NULL, NULL,
    function (event)
      if list_mode then
         list_mode = false
      else
         list_mode = true
      end
      mrg:queue_draw(nil)
      event:stop_propagate()
    end)

  if list_mode then
    mrg:add_binding("backspace", NULL, NULL,
    function (event)
      if mrg:get_cursor_pos() > 0 or item_no == -1 then
      else
        local str = zn:deref(zn:list_children(id)[item_no-1]) ..
                    zn:deref(zn:list_children(id)[item_no])
        zn:remove_child(id, item_no-1)
        zn:remove_child(id, item_no-1)
        zn:add_child_at(id, item_no-1, zn:string(str))
        item_no = item_no - 1
        mrg:queue_draw(nil)
        mrg:set_cursor_pos(0)
        event:stop_propagate() 
      end
    end)

  mrg:add_binding("return", NULL, NULL,
    function (event)
      if item_no < 0 then return end
      local str = zn:deref(zn:list_children(id)[item_no])
      local cursor = mrg:get_cursor_pos()
      zn:remove_child(id, item_no)
      mrg:set_cursor_pos(0)
      zn:add_child_at(id, item_no, zn:string(str:sub(cursor + 1, -1)))
      zn:add_child_at(id, item_no, zn:string(str:sub(0, cursor)))
      item_no = item_no + 1
      mrg:queue_draw(nil)
    end)
    mrg:add_binding("escape", NULL, NULL,
      function (event)
         list_mode = false
         mrg:queue_draw(nil)
         event:stop_propagate() 
      end)
  else
    mrg:add_binding("right", NULL, NULL,
      function (event)
         if item_no >= 0 then
           cgo(zn:list_children(id)[item_no])
           event:stop_propagate() 
         end
      end)
    mrg:add_binding("left", NULL, NULL,
      function (event)
        if item_no >= 0 or (item_no == -1 and mrg:get_cursor_pos() == 0  ) then
          cback()
          event:stop_propagate() 
        end
      end)

    mrg:add_binding("return", NULL, NULL,
      function (event)
         list_mode = true
         mrg:queue_draw(nil)
         event:stop_propagate() 
      end)
    mrg:add_binding("backspace", NULL, NULL,
      function (event)
         if item_no > 1 then
           zn:remove_child(id, item_no - 1)
           item_no = item_no - 1
         mrg:queue_draw(nil)
         event:stop_propagate() 
         end
      end)
    mrg:add_binding("delete", NULL, NULL,
      function (event)
         if item_no >= 0 then
           zn:remove_child(id, item_no)
           mrg:queue_draw(nil)
           event:stop_propagate() 
         end
      end)
  end
end

function view_image(mrg)
    local title = zn:get_key(id, zn:string("dc:title"))
    if title then
      mrg:print(zn:deref(title))
    else
      mrg:print(mimetype)
    end

    mrg:add_binding("left", NULL, NULL,
      function (event)
        if item_no >= 0 or (item_no == -1 and mrg:get_cursor_pos() == 0  ) then
          cback()
          event:stop_propagate() 
        end
      end)
end

mrg:set_ui(
function (mrg, data)
  local mimetype = zn:get_mime_type(id)

  if mimetype == "text/plain" then
    view_list(mrg)
  elseif mimetype == "text/png" 
      or mimetype == "text/jpeg" then
  else
    view_image(mrg)
  end

  mrg:add_binding("control-q", NULL, NULL, function (event) mrg:quit() end)
end)

mrg:set_title("zn")
mrg:main()

