local M = {}

function M.for_path(path)
   if path:has_suffix(".gif") or
      path:has_suffix(".GIF") then
     return "image/gif";
   elseif path:has_suffix(".png") or 
      path:has_suffix(".PNG") then
      return "image/png"
   elseif path:has_suffix(".svg") or 
      path:has_suffix(".SVG") then
      return "image/svg"
   elseif path:has_suffix(".html") or 
      path:has_suffix(".HTML") then
      return "text/html"
   elseif path:has_suffix(".jpg") or
            path:has_suffix(".jpeg") or
            path:has_suffix(".JPEG") or
            path:has_suffix(".JPG") 
     then
       return "image/jpeg"
   elseif path:has_suffix("README") or 
      path:has_suffix(".txt") or
      path:has_suffix("Makefile") or
      path:has_suffix("Makefile.am") or
      path:has_suffix("configure") or
      path:has_suffix('.c') or 
      path:has_suffix('.md') or 
      path:has_suffix('.pc') or 
      path:has_suffix('.inc') or 
      path:has_suffix('.h') or 
      path:has_suffix('.css') or 
      path:has_suffix(".lua") then
      return "text/plain"
   end
   return "unknown"
end

return M
