#!/usr/bin/env luajit

local Mrg = require('mrg')
local Zn = require('zn');

local zn=Zn.new()
local mrg=Mrg.new(640,480);

local item_no = 0;

local css = [[
  .body { margin: 1em; margin-top:0;}
  .title {font-size: 30px; width: 100%; color: black;
    margin-bottom: 1em;
  }
  .item {font-size: 20px; width: 100%; color: black; }
  .children { color : red }
  .parents {font-size: 10px; display: block-inline; padding-right: 4em; }
]]

title="todo"
if (#arg >= 1) then title = arg[1] end

id=zn:string(title)

mrg:css_set(css)

mrg:set_ui(
function (mrg, data)
  mrg:start("div.body")
  mrg:start("div.title")

  if item_no == -1 then
  mrg:edit_start(
       function(new_text)
         id=zn:string(new_text)
         mrg:queue_draw(nil)
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

  mrg:close()

  for i = 0, zn:count_parents(id)-1 do
    local parent = zn:get_parents(id)[i]

    mrg:start("div.item.parents")
    mrg:text_listen(Mrg.TAP, function()
       id=parent
       item_no=0
       mrg:queue_draw(nil)
    end)
    mrg:print(zn:deref(parent))
    mrg:text_listen_done()
    mrg:close()
  end

  for i = 0, zn:count_children(id)-1 do
    local child = zn:list_children(id)[i]
    if (zn:count_children(child) > 0) then
      mrg:text_listen(Mrg.TAP, function()
         id=child
         mrg:queue_draw(nil)
      end)
      end
      if zn:count_children(child) > 0 then
        mrg:start("div.item.children")
      else
        mrg:start("div.item")
      end
      if i == item_no then
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
      if item_no > zn:count_children(id) then item_no = zn:count_children(id) end
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
      local str = zn:deref(zn:list_children(id)[item_no])
      local cursor = mrg:get_cursor_pos()
      zn:remove_child(id, item_no)
      mrg:set_cursor_pos(0)
      zn:add_child_at(id, item_no, zn:string(str:sub(cursor + 1, -1)))
      zn:add_child_at(id, item_no, zn:string(str:sub(0, cursor)))
      item_no = item_no + 1
      mrg:queue_draw(nil)
    end)
  mrg:add_binding("control-q", NULL, NULL, function (event) mrg:quit() end)

end)

mrg:set_title(title)
mrg:main()

