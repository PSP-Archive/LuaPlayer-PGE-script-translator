--[[
*******************************************************************

   LuaPlayer/PGE script translator
   -------------------------------
  Scripted using the PGE Lua API,this header script can be run
 with dofile(). Then call method System.LP2PGE() to allow the
 pseudo-LuaPlayer 0.2 API to be used in PGE Lua scripts.

  This can help to 'port' existing LuaPlayer scripts to PGE Lua.

  Some scripts work better than others. Fonts and transparency
 effects do not translate well.

*******************************************************************

  Notes/Caveats
  -------------

  System.md5sum() returns a dummy md5.

  screen.waitVblankStart() is approximate
     To Vsync page flipping, replace
       screen.waitVblankStart() ; screen.flip()
     with
       screen.flip(true)

  Image.load() only loads .PNG files

  pge.texture.toram() is unpredictable. Introducing a short
   pge.delay(), and tuning the garbage collector seems to help.

  pge.texture.tovram() is unpredictable.
   ( Automatic Lua memory management may not work in VRAM ?)

  Image:fontPrint() and screen:fontPrint()
     both draw an opaque black background. 
     An optional extra parameter can be added to specify the color.
     e.g.  screen:fontPrint(Font,x,y,str,textcolor,BACKGROUND_Color)
     (background alpha is always 255)

  The fontPrint mapping between LuaPlayer & PGE is very weak.
    Size and resolution are only loose approximations,and
    rendering is slow.

  VERA.TTF is embedded in this script for use in
       Font.createMonoSpaced() and Font.createProportional()
   (The copyright notice can be found in the TRUETYPE FONTS
     section in System.VERA).

  Font:setCharSize(width,height,dpiX,dpiY)
   is implemented as Font:setPixelSizes(width,height)

  image1:blit(x,y,image1,...), and image1:blit(x,y,screen,...)
     are unsupported.

  Color screen:pixel(x,y) is not supported. returns a default color

  The alpha bool in Image:blit() and screen:blit() is unsupported.

  blitting sub-images is unpredictable. Small images sometimes get
   scrambled.

  Alpha in colors is unpredictable. Usually doesn't work.

  Sound.load() only loads .WAV files. Some .wav types that work in
   LuaPlayer don't work in PGE Lua.

  GU methods are not supported
  SIO methods are not supported
  Battery methods are not supported.
  System.powerTick() is not supported
  IRDA methods are not supported.
  Music and Soundsystem methods are not supported.
  WLAN methods are not yet supported

  System.Quit() is supported.

  ( Apart from System.Quit(), the extra functions of the 
    LuaPlayer 0.2 extensions, Mod3 and HM, are not supported)

  To compare Colors, use the bool function
    Color.equal(colr1,colr2)
   to replace 
    colr1==colr2


  For fast graphics replace LuaPlayer graphics function calls
   with PGE script segments

  Use System.pgegfx() to clear VRAM, before any PGE script segment
    that uses the pge.texture or pge.gfx modules, or after any
    LuaPlayer graphics function calls.

  An Image object has a PGE texture as a property. It can be
    indexed using Image.PGETexture 
  Likewise: Timer.PGETimer,
            Color.PGEColor,
            Font.PGEFont

*******************************************************************
]]--


--** Bindings **--

--SYSTEM--

System = {}

System.LP2PGE = function()

  --System constants
  System.SCRW    = 480           --Screen width
  System.SCRH    = 272           --Screen height
  System.TMRES   = 1000          --Timer ticks/sec
  System.NEWSTR  = ""            --empty string
  System.FDV     = "/"           --file path divider
  System.FPWDF   = 8             --default TTF character width
  System.FPHDF   = 12            --default TTF character height
  System.FWDMX   = 24            --maximum TTF character width
  System.FHGMX   = 32            --maximum TTF character height
  System.TTFONT  = "VERA.TTF"    --TTF to load for Font creation
  System.FCHSPC  = 13            --Font Character spacing constant
  System.FHGFAC  = 26/25         --Font height adjustment factor
  System.FWDFC0  = 1.021         --Font Text width trimmer
  System.FBHGT   = 52            --Font reference height
  System.FBWID   = 32            --Font reference width
  System.FPROPR  = 1             --System proportional id
  System.FMSPAC  = 2             --System monospace id
  System.F_LOAD  = 3             --TTF id
  System.VOLTAGE = 3.6           --nominal battery voltage
  System.DOTDOT  = ".."          --parent folder identifier
  System.DRIVE1  = "ms0:"        --drive identifier
  System.FDV     = "/"           --filepath divider

  System.RPTH    = System.DRIVE1..System.FDV
  System.FBCOL   = pge.gfx.createcolor(0,0,0,255)  --Font background
  System.SPXDF   = pge.gfx.createcolor(255,0,0,255)
  System.DOTDIR  = {name=".",directory=true,size=0}
  System.DDOTDIR = {name=System.DOTDOT,directory=true,size=0}
 
  System.md5blk = ""            --md5 default string
  for i = 1,16 do
    System.md5blk = System.md5blk..string.byte(252)
  end

  --parameter types
  System.NUMBER = type(0)                --number type
  System.STRING = type(System.NEWSTR)    --string type
  System.TABLE  = type(System)           --table type
  System.BOOL   = type(true)             --Boolean type

  --System variables
  System.dpath = System.NEWSTR      --previous directory path
  System.flist = {}                 --file list
  System.quickImage = nil           --gfx enabled Image
  System.EbPath = pge.dir.getcwd()  --PGELua Eboot folder
  System.fpath = System.NEWSTR      --file path

--utilities

  System.filePath = function(fstr)
  --return normalised path string for file string (fstr)
  --file string may include drive id and directory id
  --defaults are current drive and root directory
 
    if type(fstr)~=System.STRING then fstr = System.NEWSTR end

    if string.find(fstr,System.FDV) then
      if string.find(string.lower(fstr),System.RPTH) then
        return fstr
      else
        if string.sub(fstr,1,1)==System.FDV then
          return System.DRIVE1..fstr
        end
      end
    end
    return pge.dir.getcwd()..System.FDV..fstr 
  end
  
  --methods
  
  System.currentDirectory=function(path)
    System.dpath = pge.dir.getcwd()
    if string.lower(System.dpath)==System.DRIVE1 then
      System.dpath = System.RPTH..System.NEWSTR
    end
    if path and type(path)==System.STRING and path~=System.NEWSTR then
      path = System.filePath(path)
      if string.sub(path,-2)==System.DOTDOT then
        pge.dir.chdir(System.DOTDOT)
        path = pge.dir.getcwd()
      end
      if pge.dir.exists(path) then pge.dir.chdir(path) end
    end
    return System.dpath
  end
  
  System.listDirectory = function(path)
    if (not path) or (type(path)~=System.STRING) or
       (not pge.dir.exists(path)) then
      path = pge.dir.getcwd()
      if string.lower(System.dpath)==System.DRIVE1 then
        System.dpath = System.RPTH..System.NEWSTR
      end
    else
      path = string.lower(System.filePath(path))
    end
    System.flist = {}
    System.dir = pge.dir.open(path)
    if System.dir then
      System.flist = System.dir:read()
      System.dir:close()
      for index, entry in ipairs(System.flist) do 
        entry.directory = entry.dir
      end 
    end
    table.insert(System.flist,1,System.DOTDIR)
    if path~=System.DRIVE1 and path~=System.RPTH then
      table.insert(System.flist,2,System.DDOTDIR)
    end
    return System.flist
  end
  
  System.createDirectory = pge.dir.mkdir
  System.removeDirectory = pge.dir.rmdir
  System.removeFile = pge.file.remove
  
  pge.usb.init()
  System.usbDiskModeActivate = pge.usb.activate
  System.usbDiskModeDeactivate = pge.usb.deactivate

  System.sleep  = function(ms) return pge.delay(ms*1000) end
  System.md5sum = function() return System.md5blk end
  System.powerTick = function() end

  System.powerIsPowerOnline = function() return false end
  System.powerIsBatteryExist = function() return false end
  System.powerIsBatteryCharging = function() return false end
  System.powerGetBatteryChargingStatus = function() return 0 end
  System.powerIsLowBattery = function() return false end
  System.powerGetBatteryLifePercent = function() return 0 end
  System.powerGetBatteryLifeTime = function() return 0 end
  System.powerGetBatteryTemp = function() return 0 end
  System.powerGetBatteryVolt = function() return System.VOLTAGE end

  System.sioInit  = function(baudrate) end
  System.sioWrite = function(string) end
  System.sioRead  = function() return System.NEWSTR end

  System.irdaInit  = function() end 
  System.irdaWrite = function(string) end
  System.irdaRead  = function() return System.NEWSTR end

  System.getFreeMemory = pge.utils.freeram

--CONTROLS--

  Controls=
  {
     --methods
     read,         --read controls
     isctrl,       --control metatype test
  
     --properties
     pad,
  }

  --methods

  Controls.read = function()
    pge.controls.update()

    local ctrl = {} ; setmetatable(ctrl,{__index=Controls})
    ctrl.pad = {}
    ctrl.pad.select   = pge.controls.held(PGE_CTRL_SELECT)
    ctrl.pad.start    = pge.controls.held(PGE_CTRL_START)
    ctrl.pad.up       = pge.controls.held(PGE_CTRL_UP)
    ctrl.pad.down     = pge.controls.held(PGE_CTRL_DOWN)
    ctrl.pad.left     = pge.controls.held(PGE_CTRL_LEFT)
    ctrl.pad.right    = pge.controls.held(PGE_CTRL_RIGHT)
    ctrl.pad.l        = pge.controls.held(PGE_CTRL_LTRIGGER)
    ctrl.pad.r        = pge.controls.held(PGE_CTRL_RTRIGGER)
    ctrl.pad.triangle = pge.controls.held(PGE_CTRL_TRIANGLE)
    ctrl.pad.circle   = pge.controls.held(PGE_CTRL_CIRCLE)
    ctrl.pad.cross    = pge.controls.held(PGE_CTRL_CROSS)
    ctrl.pad.square   = pge.controls.held(PGE_CTRL_SQUARE)
  
    ctrl.pad.analogX  = pge.controls.analogx()
    ctrl.pad.analogY  = pge.controls.analogy()
  
    return ctrl
  end
  
  function Controls.isctrl(ctr)
    return type(ctr)==System.TABLE and ctr.pad and 
           type(ctr.pad)==System.TABLE
  end
  
  --metamethods
  
  function Controls:select()
    if Controls.isctrl(self) then return self.pad.select end
  end
  function Controls:start()
    if Controls.isctrl(self) then return self.pad.start end
  end
  function Controls:up()
    if Controls.isctrl(self) then return self.pad.up end
  end
  function Controls:down()
    if Controls.isctrl(self) then return self.pad.down end
  end
  function Controls:left()
    if Controls.isctrl(self) then return self.pad.left end
  end
  function Controls:right()
    if Controls.isctrl(self) then return self.pad.right end
  end
  function Controls:triangle()
    if Controls.isctrl(self) then return self.pad.triangle end
  end
  function Controls:circle()
    if Controls.isctrl(self) then return self.pad.circle end
  end
  function Controls:cross()
    if Controls.isctrl(self) then return self.pad.cross end
  end
  function Controls:square()
    if Controls.isctrl(self) then return self.pad.square end
  end
  function Controls:l()
    if Controls.isctrl(self) then return self.pad.l end
  end
  function Controls:r()
    if Controls.isctrl(self) then return self.pad.r end
  end
  function Controls:analogX()
    if Controls.isctrl(self) then return self.pad.analogX end
  end
  function Controls:analogY()
    if Controls.isctrl(self) then return self.pad.analogY end
  end


--TIMER

  Timer =
  {
     --methods
     new,

     --properties
     PGETimer,
     starttime,
     stoptime,
     resettime,
     deltatime,
     stopped,
     rst,
  }

  --methods

  Timer.new = function(time1)
    if not time1 or type(time1)~=System.NUMBER then time1 = 0 end
  
    local tmr = {} ; setmetatable(tmr,{__index=Timer})
  
    tmr.PGETimer  = pge.timer.create()
    tmr.starttime = math.floor(time1)
    tmr.stoptime  = tmr.starttime
    tmr.resettime = tmr.starttime
    tmr.deltatime = 0
    tmr.stopped   = true
    tmr.rst       = true

    return tmr
  end

  --metamethods

  function Timer:time()
  --Returns in milliseconds since the timer started/resumed.
  
    local tmr = self
  
    if not tmr.stopped then
      tmr.deltatime = math.floor(tmr.PGETimer:peekdelta()*System.TMRES)
    end
    return tmr.deltatime+tmr.starttime
  end
  
  function Timer:start()
  --Starts to tick the timer (incrementing by one every millisecond),
  -- or resumes to tick after being stopped.
  -- Returns the current time() value.
  
    local tmr = self
  
    if tmr.stopped then
      tmr.PGETimer:update()
      tmr.stopped = false
      tmr.starttime = tmr.stoptime
      return tmr.starttime
    else
      tmr.stoptime = tmr:time()
      if not tmr.rst then tmr.starttime = 0 end
      tmr.rst = false
      tmr.PGETimer:update()
      return tmr.stoptime
    end
  
  end
  
  function Timer:stop()
  --Stops the timer.
  --Returns the current time().
  --Subsequent time() calls return the value when stopped.
  --If the timer is stopped, this call is the same as time().
    local tmr = self
  
    tmr.stoptime = tmr:time()
    tmr.stopped = true
    return tmr.stoptime
  end
  
  function Timer:reset(time1)
  --Resets the timer to 0 by default or startTime in milliseconds
  -- and holds the timer. Returns the time before resetted to the
  -- new value.
    if not time1 or type(time1)~=System.NUMBER then time1 = 0 end
  
    local tmr = self
  
    tmr.resettime = tmr:stop()
    tmr.starttime = math.floor(time1)
    tmr.stoptime  = tmr.starttime
    tmr.deltatime = 0
    tmr.rst       = true
    tmr.stopped   = true

    return tmr.resettime
  end
  


--COLOURS--
  Color =
  {
     --methods
     new,
     equal,
  
     --properties
     PGEColor,
     ctab,
  }
  
  Color.new = function(r,g,b,a)
  --Creates a new color object with the specified RGBA values.
    if not r or type(r)~=System.NUMBER then r = 0 end
    if not g or type(g)~=System.NUMBER then g = 0 end
    if not b or type(b)~=System.NUMBER then b = 0 end
    if not a or type(a)~=System.NUMBER then a = 255 end
  
    local clr = {} ; setmetatable(clr,{__index=Color})
    clr.PGEColor = pge.gfx.createcolor(r,g,b,a)
    clr.ctab = {r=r,g=g,b=b,a=a}
    return clr
  end
  
  Color.equal = function(c1,c2)
    return c1.ctab.r==c2.ctab.r and
           c1.ctab.g==c2.ctab.g and
           c1.ctab.b==c2.ctab.b and
           c1.ctab.a==c2.ctab.a 
  end
  
  --metamethods
  function Color:colors() return self.ctab end
  

--TRUETYPE FONTS--

  System.VERA=
    "\0\1\0\0\0\16\1\0\0\4\0\0OS\47\50¥_ı*\0\0™,\0\0\0VPCLT!?Õ\14"
  .."\0\0™Ñ\0\0\0\54cmap§√Ë†\0\0ù®\0\0\3Xcvt Èó\7\12\0\0\31\8\0\0"
  .."\2\48fpgm∆p(\22\0\0(T\0\0\0ågasp\0\7\0\7\0\0¿\4\0\0\0\12glyf"
  .."≠ÇÒ≈\0\0(‡\0\0t»hdmx«\51\50`\0\0™º\0\0\21HheadŸÖ•'\0\0¿\16\0"
  .."\0\0\54hhea\12?\3Ù\0\0™\8\0\0\0$hmtx\10Œµ`\0\0°\0\0\0\4\52lo"
  .."caè\1≠ô\0\0ßÃ\0\0\2\28maxp\6ä\7Ò\0\0©Ë\0\0\0 name‰£¡`\0\0\1\12"
  .."\0\0\29˙postnçÓ\93\0\0•\52\0\0\2ñprep:«¿\7\0\0!\56\0\0\7\27\0"
  .."\0\0\22\1\14\0\1\0\0\0\0\0\0\0:\0\0\0\1\0\0\0\0\0\1\0\24\0:\0"
  .."\1\0\0\0\0\0\2\0\5\0h\0\1\0\0\0\0\0\3\0\24\0:\0\1\0\0\0\0\0\4"
  .."\0\24\0:\0\1\0\0\0\0\0\5\0\12\0m\0\1\0\0\0\0\0\6\0\27\0R\0\1"
  .."\0\0\0\0\0\7\0\48\0∂\0\1\0\0\0\0\0\8\0\14\8u\0\1\0\0\0\0\0\11"
  .."\0\24\9å\0\1\0\0\0\0\0\13\9\19\0y\0\3\0\1\4\9\0\0\0t\9§\0\3\0"
  .."\1\4\9\0\1\0\48\10\24\0\3\0\1\4\9\0\2\0\10\10t\0\3\0\1\4\9\0"
  .."\3\0\48\10\24\0\3\0\1\4\9\0\4\0\48\10\24\0\3\0\1\4\9\0\5\0\24"
  .."\10~\0\3\0\1\4\9\0\6\0\54\10H\0\3\0\1\4\9\0\7\0`\11\16\0\3\0"
  .."\1\4\9\0\8\0\28\26é\0\3\0\1\4\9\0\11\0\48\28º\0\3\0\1\4\9\0\13"
  .."\18&\10ñCopyright (c) \50\48\48\51 by Bitstream, Inc\46 All "
  .."Rights Reserved\46Bitstream Vera Sans MonoBitstreamVeraSansM"
  .."ono\45RomanRelease \49\46\49\48Copyright (c) \50\48\48\51 by"
  .." Bitstream, Inc\46\13\10All Rights Reserved\46\13\10Bitstrea"
  .."m Vera is a trademark of Bitstream, Inc\46\13\10\13\10Permis"
  .."sion is hereby granted, free of charge, to any person obtain"
  .."ing a copy of the fonts accompanying this license (\34Fonts\34"
  ..") and associated documentation files (the \34Font Software\34"
  .."), to reproduce and distribute the Font Software, including "
  .."without limitation the rights to use, copy, merge, publish, "
  .."distribute, and\47or sell copies of the Font Software, and t"
  .."o permit persons to whom the Font Software is furnished to d"
  .."o so, subject to the following conditions:\13\10\13\10The ab"
  .."ove copyright and trademark notices and this permission noti"
  .."ce shall be included in all copies of one or more of the Fon"
  .."t Software typefaces\46\13\10\13\10The Font Software may be "
  System.VERA=System.VERA
  .."modified, altered, or added to, and in particular the design"
  .."s of glyphs or characters in the Fonts may be modified and a"
  .."dditional glyphs or characters may be added to the Fonts, on"
  .."ly if the fonts are renamed to names not containing either t"
  .."he words \34Bitstream\34 or the word \34Vera\34\46\13\10\13\10"
  .."This License becomes null and void to the extent applicable "
  .."to Fonts or Font Software that has been modified and is dist"
  .."ributed under the \34Bitstream Vera\34 names\46\13\10\13\10T"
  .."he Font Software may be sold as part of a larger software pa"
  .."ckage but no copy of one or more of the Font Software typefa"
  .."ces may be sold by itself\46\13\10\13\10THE FONT SOFTWARE IS"
  .." PROVIDED \34AS IS\34, WITHOUT WARRANTY OF ANY KIND, EXPRESS"
  .." OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF "
  .."MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINF"
  .."RINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT\46"
  .." IN NO EVENT SHALL BITSTREAM OR THE GNOME FOUNDATION BE LIAB"
  .."LE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY "
  .."GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAM"
  .."AGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, A"
  .."RISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOF"
  .."TWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE\46\13\10\13"
  .."\10Except as contained in this notice, the names of Gnome, t"
  .."he Gnome Foundation, and Bitstream Inc\46, shall not be used"
  .." in advertising or otherwise to promote the sale, use or oth"
  .."er dealings in this Font Software without prior written auth"
  .."orization from the Gnome Foundation or Bitstream Inc\46, res"
  .."pectively\46 For further information, contact: fonts at gnom"
  .."e dot org\46http:\47\47www\46bitstream\46com\0C\0o\0p\0y\0r\0"
  .."i\0g\0h\0t\0 \0(\0c\0)\0 \0\50\0\48\0\48\0\51\0 \0b\0y\0 \0B"
  .."\0i\0t\0s\0t\0r\0e\0a\0m\0,\0 \0I\0n\0c\0\46\0 \0A\0l\0l\0 \0"
  .."R\0i\0g\0h\0t\0s\0 \0R\0e\0s\0e\0r\0v\0e\0d\0\46\0B\0i\0t\0s"
  .."\0t\0r\0e\0a\0m\0 \0V\0e\0r\0a\0 \0S\0a\0n\0s\0 \0M\0o\0n\0o"
  System.VERA=System.VERA
  .."\0B\0i\0t\0s\0t\0r\0e\0a\0m\0V\0e\0r\0a\0S\0a\0n\0s\0M\0o\0n"
  .."\0o\0\45\0R\0o\0m\0a\0n\0R\0e\0l\0e\0a\0s\0e\0 \0\49\0\46\0\49"
  .."\0\48\0C\0o\0p\0y\0r\0i\0g\0h\0t\0 \0(\0c\0)\0 \0\50\0\48\0\48"
  .."\0\51\0 \0b\0y\0 \0B\0i\0t\0s\0t\0r\0e\0a\0m\0,\0 \0I\0n\0c\0"
  .."\46\0\13\0\10\0A\0l\0l\0 \0R\0i\0g\0h\0t\0s\0 \0R\0e\0s\0e\0"
  .."r\0v\0e\0d\0\46\0\13\0\10\0B\0i\0t\0s\0t\0r\0e\0a\0m\0 \0V\0"
  .."e\0r\0a\0 \0i\0s\0 \0a\0 \0t\0r\0a\0d\0e\0m\0a\0r\0k\0 \0o\0"
  .."f\0 \0B\0i\0t\0s\0t\0r\0e\0a\0m\0,\0 \0I\0n\0c\0\46\0\13\0\10"
  .."\0\13\0\10\0P\0e\0r\0m\0i\0s\0s\0i\0o\0n\0 \0i\0s\0 \0h\0e\0"
  .."r\0e\0b\0y\0 \0g\0r\0a\0n\0t\0e\0d\0,\0 \0f\0r\0e\0e\0 \0o\0"
  .."f\0 \0c\0h\0a\0r\0g\0e\0,\0 \0t\0o\0 \0a\0n\0y\0 \0p\0e\0r\0"
  .."s\0o\0n\0 \0o\0b\0t\0a\0i\0n\0i\0n\0g\0 \0a\0 \0c\0o\0p\0y\0"
  .." \0o\0f\0 \0t\0h\0e\0 \0f\0o\0n\0t\0s\0 \0a\0c\0c\0o\0m\0p\0"
  .."a\0n\0y\0i\0n\0g\0 \0t\0h\0i\0s\0 \0l\0i\0c\0e\0n\0s\0e\0 \0"
  .."(\0\34\0F\0o\0n\0t\0s\0\34\0)\0 \0a\0n\0d\0 \0a\0s\0s\0o\0c\0"
  .."i\0a\0t\0e\0d\0 \0d\0o\0c\0u\0m\0e\0n\0t\0a\0t\0i\0o\0n\0 \0"
  .."f\0i\0l\0e\0s\0 \0(\0t\0h\0e\0 \0\34\0F\0o\0n\0t\0 \0S\0o\0f"
  .."\0t\0w\0a\0r\0e\0\34\0)\0,\0 \0t\0o\0 \0r\0e\0p\0r\0o\0d\0u\0"
  .."c\0e\0 \0a\0n\0d\0 \0d\0i\0s\0t\0r\0i\0b\0u\0t\0e\0 \0t\0h\0"
  .."e\0 \0F\0o\0n\0t\0 \0S\0o\0f\0t\0w\0a\0r\0e\0,\0 \0i\0n\0c\0"
  .."l\0u\0d\0i\0n\0g\0 \0w\0i\0t\0h\0o\0u\0t\0 \0l\0i\0m\0i\0t\0"
  .."a\0t\0i\0o\0n\0 \0t\0h\0e\0 \0r\0i\0g\0h\0t\0s\0 \0t\0o\0 \0"
  .."u\0s\0e\0,\0 \0c\0o\0p\0y\0,\0 \0m\0e\0r\0g\0e\0,\0 \0p\0u\0"
  .."b\0l\0i\0s\0h\0,\0 \0d\0i\0s\0t\0r\0i\0b\0u\0t\0e\0,\0 \0a\0"
  .."n\0d\0\47\0o\0r\0 \0s\0e\0l\0l\0 \0c\0o\0p\0i\0e\0s\0 \0o\0f"
  .."\0 \0t\0h\0e\0 \0F\0o\0n\0t\0 \0S\0o\0f\0t\0w\0a\0r\0e\0,\0 "
  .."\0a\0n\0d\0 \0t\0o\0 \0p\0e\0r\0m\0i\0t\0 \0p\0e\0r\0s\0o\0n"
  .."\0s\0 \0t\0o\0 \0w\0h\0o\0m\0 \0t\0h\0e\0 \0F\0o\0n\0t\0 \0S"
  .."\0o\0f\0t\0w\0a\0r\0e\0 \0i\0s\0 \0f\0u\0r\0n\0i\0s\0h\0e\0d"
  .."\0 \0t\0o\0 \0d\0o\0 \0s\0o\0,\0 \0s\0u\0b\0j\0e\0c\0t\0 \0t"
  .."\0o\0 \0t\0h\0e\0 \0f\0o\0l\0l\0o\0w\0i\0n\0g\0 \0c\0o\0n\0d"
  .."\0i\0t\0i\0o\0n\0s\0:\0\13\0\10\0\13\0\10\0T\0h\0e\0 \0a\0b\0"
  System.VERA=System.VERA
  .."o\0v\0e\0 \0c\0o\0p\0y\0r\0i\0g\0h\0t\0 \0a\0n\0d\0 \0t\0r\0"
  .."a\0d\0e\0m\0a\0r\0k\0 \0n\0o\0t\0i\0c\0e\0s\0 \0a\0n\0d\0 \0"
  .."t\0h\0i\0s\0 \0p\0e\0r\0m\0i\0s\0s\0i\0o\0n\0 \0n\0o\0t\0i\0"
  .."c\0e\0 \0s\0h\0a\0l\0l\0 \0b\0e\0 \0i\0n\0c\0l\0u\0d\0e\0d\0"
  .." \0i\0n\0 \0a\0l\0l\0 \0c\0o\0p\0i\0e\0s\0 \0o\0f\0 \0o\0n\0"
  .."e\0 \0o\0r\0 \0m\0o\0r\0e\0 \0o\0f\0 \0t\0h\0e\0 \0F\0o\0n\0"
  .."t\0 \0S\0o\0f\0t\0w\0a\0r\0e\0 \0t\0y\0p\0e\0f\0a\0c\0e\0s\0"
  .."\46\0\13\0\10\0\13\0\10\0T\0h\0e\0 \0F\0o\0n\0t\0 \0S\0o\0f\0"
  .."t\0w\0a\0r\0e\0 \0m\0a\0y\0 \0b\0e\0 \0m\0o\0d\0i\0f\0i\0e\0"
  .."d\0,\0 \0a\0l\0t\0e\0r\0e\0d\0,\0 \0o\0r\0 \0a\0d\0d\0e\0d\0"
  .." \0t\0o\0,\0 \0a\0n\0d\0 \0i\0n\0 \0p\0a\0r\0t\0i\0c\0u\0l\0"
  .."a\0r\0 \0t\0h\0e\0 \0d\0e\0s\0i\0g\0n\0s\0 \0o\0f\0 \0g\0l\0"
  .."y\0p\0h\0s\0 \0o\0r\0 \0c\0h\0a\0r\0a\0c\0t\0e\0r\0s\0 \0i\0"
  .."n\0 \0t\0h\0e\0 \0F\0o\0n\0t\0s\0 \0m\0a\0y\0 \0b\0e\0 \0m\0"
  .."o\0d\0i\0f\0i\0e\0d\0 \0a\0n\0d\0 \0a\0d\0d\0i\0t\0i\0o\0n\0"
  .."a\0l\0 \0g\0l\0y\0p\0h\0s\0 \0o\0r\0 \0c\0h\0a\0r\0a\0c\0t\0"
  .."e\0r\0s\0 \0m\0a\0y\0 \0b\0e\0 \0a\0d\0d\0e\0d\0 \0t\0o\0 \0"
  .."t\0h\0e\0 \0F\0o\0n\0t\0s\0,\0 \0o\0n\0l\0y\0 \0i\0f\0 \0t\0"
  .."h\0e\0 \0f\0o\0n\0t\0s\0 \0a\0r\0e\0 \0r\0e\0n\0a\0m\0e\0d\0"
  .." \0t\0o\0 \0n\0a\0m\0e\0s\0 \0n\0o\0t\0 \0c\0o\0n\0t\0a\0i\0"
  .."n\0i\0n\0g\0 \0e\0i\0t\0h\0e\0r\0 \0t\0h\0e\0 \0w\0o\0r\0d\0"
  .."s\0 \0\34\0B\0i\0t\0s\0t\0r\0e\0a\0m\0\34\0 \0o\0r\0 \0t\0h\0"
  .."e\0 \0w\0o\0r\0d\0 \0\34\0V\0e\0r\0a\0\34\0\46\0\13\0\10\0\13"
  .."\0\10\0T\0h\0i\0s\0 \0L\0i\0c\0e\0n\0s\0e\0 \0b\0e\0c\0o\0m\0"
  .."e\0s\0 \0n\0u\0l\0l\0 \0a\0n\0d\0 \0v\0o\0i\0d\0 \0t\0o\0 \0"
  .."t\0h\0e\0 \0e\0x\0t\0e\0n\0t\0 \0a\0p\0p\0l\0i\0c\0a\0b\0l\0"
  .."e\0 \0t\0o\0 \0F\0o\0n\0t\0s\0 \0o\0r\0 \0F\0o\0n\0t\0 \0S\0"
  .."o\0f\0t\0w\0a\0r\0e\0 \0t\0h\0a\0t\0 \0h\0a\0s\0 \0b\0e\0e\0"
  .."n\0 \0m\0o\0d\0i\0f\0i\0e\0d\0 \0a\0n\0d\0 \0i\0s\0 \0d\0i\0"
  .."s\0t\0r\0i\0b\0u\0t\0e\0d\0 \0u\0n\0d\0e\0r\0 \0t\0h\0e\0 \0"
  .."\34\0B\0i\0t\0s\0t\0r\0e\0a\0m\0 \0V\0e\0r\0a\0\34\0 \0n\0a\0"
  .."m\0e\0s\0\46\0\13\0\10\0\13\0\10\0T\0h\0e\0 \0F\0o\0n\0t\0 \0"
  System.VERA=System.VERA
  .."S\0o\0f\0t\0w\0a\0r\0e\0 \0m\0a\0y\0 \0b\0e\0 \0s\0o\0l\0d\0"
  .." \0a\0s\0 \0p\0a\0r\0t\0 \0o\0f\0 \0a\0 \0l\0a\0r\0g\0e\0r\0"
  .." \0s\0o\0f\0t\0w\0a\0r\0e\0 \0p\0a\0c\0k\0a\0g\0e\0 \0b\0u\0"
  .."t\0 \0n\0o\0 \0c\0o\0p\0y\0 \0o\0f\0 \0o\0n\0e\0 \0o\0r\0 \0"
  .."m\0o\0r\0e\0 \0o\0f\0 \0t\0h\0e\0 \0F\0o\0n\0t\0 \0S\0o\0f\0"
  .."t\0w\0a\0r\0e\0 \0t\0y\0p\0e\0f\0a\0c\0e\0s\0 \0m\0a\0y\0 \0"
  .."b\0e\0 \0s\0o\0l\0d\0 \0b\0y\0 \0i\0t\0s\0e\0l\0f\0\46\0\13\0"
  .."\10\0\13\0\10\0T\0H\0E\0 \0F\0O\0N\0T\0 \0S\0O\0F\0T\0W\0A\0"
  .."R\0E\0 \0I\0S\0 \0P\0R\0O\0V\0I\0D\0E\0D\0 \0\34\0A\0S\0 \0I"
  .."\0S\0\34\0,\0 \0W\0I\0T\0H\0O\0U\0T\0 \0W\0A\0R\0R\0A\0N\0T\0"
  .."Y\0 \0O\0F\0 \0A\0N\0Y\0 \0K\0I\0N\0D\0,\0 \0E\0X\0P\0R\0E\0"
  .."S\0S\0 \0O\0R\0 \0I\0M\0P\0L\0I\0E\0D\0,\0 \0I\0N\0C\0L\0U\0"
  .."D\0I\0N\0G\0 \0B\0U\0T\0 \0N\0O\0T\0 \0L\0I\0M\0I\0T\0E\0D\0"
  .." \0T\0O\0 \0A\0N\0Y\0 \0W\0A\0R\0R\0A\0N\0T\0I\0E\0S\0 \0O\0"
  .."F\0 \0M\0E\0R\0C\0H\0A\0N\0T\0A\0B\0I\0L\0I\0T\0Y\0,\0 \0F\0"
  .."I\0T\0N\0E\0S\0S\0 \0F\0O\0R\0 \0A\0 \0P\0A\0R\0T\0I\0C\0U\0"
  .."L\0A\0R\0 \0P\0U\0R\0P\0O\0S\0E\0 \0A\0N\0D\0 \0N\0O\0N\0I\0"
  .."N\0F\0R\0I\0N\0G\0E\0M\0E\0N\0T\0 \0O\0F\0 \0C\0O\0P\0Y\0R\0"
  .."I\0G\0H\0T\0,\0 \0P\0A\0T\0E\0N\0T\0,\0 \0T\0R\0A\0D\0E\0M\0"
  .."A\0R\0K\0,\0 \0O\0R\0 \0O\0T\0H\0E\0R\0 \0R\0I\0G\0H\0T\0\46"
  .."\0 \0I\0N\0 \0N\0O\0 \0E\0V\0E\0N\0T\0 \0S\0H\0A\0L\0L\0 \0B"
  .."\0I\0T\0S\0T\0R\0E\0A\0M\0 \0O\0R\0 \0T\0H\0E\0 \0G\0N\0O\0M"
  .."\0E\0 \0F\0O\0U\0N\0D\0A\0T\0I\0O\0N\0 \0B\0E\0 \0L\0I\0A\0B"
  .."\0L\0E\0 \0F\0O\0R\0 \0A\0N\0Y\0 \0C\0L\0A\0I\0M\0,\0 \0D\0A"
  .."\0M\0A\0G\0E\0S\0 \0O\0R\0 \0O\0T\0H\0E\0R\0 \0L\0I\0A\0B\0I"
  .."\0L\0I\0T\0Y\0,\0 \0I\0N\0C\0L\0U\0D\0I\0N\0G\0 \0A\0N\0Y\0 "
  .."\0G\0E\0N\0E\0R\0A\0L\0,\0 \0S\0P\0E\0C\0I\0A\0L\0,\0 \0I\0N"
  .."\0D\0I\0R\0E\0C\0T\0,\0 \0I\0N\0C\0I\0D\0E\0N\0T\0A\0L\0,\0 "
  .."\0O\0R\0 \0C\0O\0N\0S\0E\0Q\0U\0E\0N\0T\0I\0A\0L\0 \0D\0A\0M"
  .."\0A\0G\0E\0S\0,\0 \0W\0H\0E\0T\0H\0E\0R\0 \0I\0N\0 \0A\0N\0 "
  .."\0A\0C\0T\0I\0O\0N\0 \0O\0F\0 \0C\0O\0N\0T\0R\0A\0C\0T\0,\0 "
  .."\0T\0O\0R\0T\0 \0O\0R\0 \0O\0T\0H\0E\0R\0W\0I\0S\0E\0,\0 \0A"
  System.VERA=System.VERA
  .."\0R\0I\0S\0I\0N\0G\0 \0F\0R\0O\0M\0,\0 \0O\0U\0T\0 \0O\0F\0 "
  .."\0T\0H\0E\0 \0U\0S\0E\0 \0O\0R\0 \0I\0N\0A\0B\0I\0L\0I\0T\0Y"
  .."\0 \0T\0O\0 \0U\0S\0E\0 \0T\0H\0E\0 \0F\0O\0N\0T\0 \0S\0O\0F"
  .."\0T\0W\0A\0R\0E\0 \0O\0R\0 \0F\0R\0O\0M\0 \0O\0T\0H\0E\0R\0 "
  .."\0D\0E\0A\0L\0I\0N\0G\0S\0 \0I\0N\0 \0T\0H\0E\0 \0F\0O\0N\0T"
  .."\0 \0S\0O\0F\0T\0W\0A\0R\0E\0\46\0\13\0\10\0\13\0\10\0E\0x\0"
  .."c\0e\0p\0t\0 \0a\0s\0 \0c\0o\0n\0t\0a\0i\0n\0e\0d\0 \0i\0n\0"
  .." \0t\0h\0i\0s\0 \0n\0o\0t\0i\0c\0e\0,\0 \0t\0h\0e\0 \0n\0a\0"
  .."m\0e\0s\0 \0o\0f\0 \0G\0n\0o\0m\0e\0,\0 \0t\0h\0e\0 \0G\0n\0"
  .."o\0m\0e\0 \0F\0o\0u\0n\0d\0a\0t\0i\0o\0n\0,\0 \0a\0n\0d\0 \0"
  .."B\0i\0t\0s\0t\0r\0e\0a\0m\0 \0I\0n\0c\0\46\0,\0 \0s\0h\0a\0l"
  .."\0l\0 \0n\0o\0t\0 \0b\0e\0 \0u\0s\0e\0d\0 \0i\0n\0 \0a\0d\0v"
  .."\0e\0r\0t\0i\0s\0i\0n\0g\0 \0o\0r\0 \0o\0t\0h\0e\0r\0w\0i\0s"
  .."\0e\0 \0t\0o\0 \0p\0r\0o\0m\0o\0t\0e\0 \0t\0h\0e\0 \0s\0a\0l"
  .."\0e\0,\0 \0u\0s\0e\0 \0o\0r\0 \0o\0t\0h\0e\0r\0 \0d\0e\0a\0l"
  .."\0i\0n\0g\0s\0 \0i\0n\0 \0t\0h\0i\0s\0 \0F\0o\0n\0t\0 \0S\0o"
  .."\0f\0t\0w\0a\0r\0e\0 \0w\0i\0t\0h\0o\0u\0t\0 \0p\0r\0i\0o\0r"
  .."\0 \0w\0r\0i\0t\0t\0e\0n\0 \0a\0u\0t\0h\0o\0r\0i\0z\0a\0t\0i"
  .."\0o\0n\0 \0f\0r\0o\0m\0 \0t\0h\0e\0 \0G\0n\0o\0m\0e\0 \0F\0o"
  .."\0u\0n\0d\0a\0t\0i\0o\0n\0 \0o\0r\0 \0B\0i\0t\0s\0t\0r\0e\0a"
  .."\0m\0 \0I\0n\0c\0\46\0,\0 \0r\0e\0s\0p\0e\0c\0t\0i\0v\0e\0l\0"
  .."y\0\46\0 \0F\0o\0r\0 \0f\0u\0r\0t\0h\0e\0r\0 \0i\0n\0f\0o\0r"
  .."\0m\0a\0t\0i\0o\0n\0,\0 \0c\0o\0n\0t\0a\0c\0t\0:\0 \0f\0o\0n"
  .."\0t\0s\0 \0a\0t\0 \0g\0n\0o\0m\0e\0 \0d\0o\0t\0 \0o\0r\0g\0\46"
  .."\0h\0t\0t\0p\0:\0\47\0\47\0w\0w\0w\0\46\0b\0i\0t\0s\0t\0r\0e"
  .."\0a\0m\0\46\0c\0o\0m\0\0\0∏\0À\0∏\0À\0™\1ë\0∏\0f\0\0\0∏\0á\2"
  .."\127\0\2\0\2\0\2\0\2\0\2\0∏\0√\0À\0\2\0À\0∏\0∏\1À\1â\1∫\0À\0"
  .."¶\0¸\0À\0É\0Ú\1\10\3«\1\55\0É\0æ\0\0\0X\4!\0À\0è\0ú\0\2\0\2\0"
  .."è\3Á\0u\3º\0”\0…\0€\0u\3Á\1\57\3∫\0À\1”\0!\1ﬂ\0∏\0â\0\2\0\2\0"
  .."\2\0\2\0\2\3æ\0â\0√\3æ\0{\3æ\3X\1\31\1m\0§\1Æ\0\0\0{\0∏\1o\0"
  .."\127\2{\0∏\2R\0è\0Õ\4—\0\0\0Õ\0á\0á\0ì\0§\0o\0Õ\0À\0∏\0É\1ë\0"
  .."›\0¥\0ã\0Ù\0ò\2È\0Z\0¥\0∫\0≈\4!\0˛\0\14\0\2\0\2\0\2\1’\0ˆ\0\127"
  System.VERA=System.VERA
  .."\2™\2=\2f\0ã\0≈\0è\0ö\0ö\1É\0’\0s\4\0\1\10\0˛\0·\5’\2+\0§\0¥"
  .."\0ú\0\0\0b\0ú\5’\5ò\0á\2\127\5’\5’\5\0§\0\0\0\29\6∏\6\20\7#"
  .."\1”\0∏\0À\0¶\1º\1\49\2N\0”\1\10\0{\0T\3\92\3q\3€\1Ö\4#\4w\3È"
  .."\0è\2\0\3`\0j\0œ\5’\6\20\0è\7#\0è\6f\1y\4`\4`\4`\4{\0\0\0{\2"
  .."w\4`\1™\0È\6\20\7b\3¯\0{\2!\0≈\0ú\0\127\2{\0\0\0¥\2R\5N\5N\4"
  .."—\0f\0ú\0ú\0f\0ú\0è\0f\0ú\0è\6\16\0Õ\3˙\0É\0ë\2˛\1H\4F\3?\0è"
  .."\0{\4L\0ò\0¢\0\0\0'\0o\0\0\0o\3\53\0j\0o\0{\5ç\5ç\5ç\5ç\0™\0"
  .."™\0\45\5ç\3ñ\2{\0ˆ\0\127\2™\1\51\2=\0ú\2f\1ã\0è\2ˆ\0Õ\0o\3D\0"
  .."\55\0f\0\29\5Ó\0Ö\1¥\6\20\0\0\7}\0s\5’\0\0\20\0π\2Ä\1\21≤î\93"
  .."\5A\28\1\21\0ñ\0\3\1\21\0Ä\0\4\1\20\0˛\0\3\1\19\0˛\0\3\1\18\0"
  .."\18\0\3\1\17\0˛\0\3\1\16\0˛\0\3\1\15\0ö\0\3\1\14\0˛\0\3\1\13"
  .."≤ÎG\5A%\1\13\0}\0\3\1\12\0%\0\3\1\11\0\50\0\3\1\10\0ñ\0\3\1\9"
  .."\0˛\0\3\1\8\0\14\0\3\1\7\0˛\0\3\1\6\0%\0\3\1\5\0˛\0\3\1\4\0\14"
  .."\0\3\1\3\0%\0\3\1\2\0˛\0\3\1\1@Y˛\3˛˛\3˝}\3¸˛\3˚˛\3˙\50\3˘ª\3"
  .."¯}\3˜ˆå\5˜˛\3˜¿\4ˆıY\5ˆå\3ˆÄ\4ıÙ&\5ıY\3ı@\4Ù&\3ÛÚ\47\5Û˙\3Ú\47"
  .."\3Ò˛\3˛\3Ô\50\3Ó\20\3Ìñ\3ÏÎG\5Ï˛\3Ï∏ˇ—@ˇ\4ÎG\3ÍÈd\5Íñ\3Èd\3"
  .."Ë˛\3ÁÊ\27\5Á˛\3Ê\27\3Â˛\3‰k\3„˛\3‚ª\3·‡\25\5·˙\3‡\25\3ﬂñ\3ﬁ˛"
  .."\3›˛\3‹€\21\5‹˛\3€\21\3⁄ñ\3Ÿÿ\21\5Ÿ˛\3ÿç\11\5ÿ\21\3◊}\3÷:\3’"
  .."ç\11\5’:\3‘˛\3”“\10\5”˛\3“\10\3—˛\3–˛\3œä\17\5œ\28\3Œ\22\3Õ˛"
  .."\3Ãñ\3Àã%\5À˛\3 ˛\3…}\3»˛\3«˛\3∆˛\3≈ö\13\5ƒ˛\3√˛\3¬˛\3¡˛\3¿ç"
  .."\11\5¿\20\3ø\12\3æΩª\5æ˛\3Ωº\93\5Ωª\3ΩÄ\4ºª%\5º\93\3º@\4ª%\3"
  .."∫˛\3πñ\3∏èA\5∑˛\3∂èA\5∂˙\3µö\13\5¥˛\3≥d\3≤d\3±\14\3∞\18\3Ø˛\3"
  .."Æ˛@˝\3≠˛\3¨˛\3´\18\3™˛\3©®\14\5©\50\3®\14\3ß¶\17\5ß(\3¶\17\3"
  .."•§\45\5•}\3§\45\3£˛\3¢˛\3°˛\3†ü\25\5†d\3üû\16\5ü\25\3û\16\3ù"
  .."\10\3ú˛\3õö\13\5õ˛\3ö\13\3ôò\46\5ô˛\3ò\46\3óèA\5óñ\3ñïª\5ñ˛\3"
  .."ïî\93\5ïª\3ïÄ\4îê%\5î\93\3î@\4ì˛\3í˛\3ëê%\5ëª\3ê%\3èã%\5èA\3"
  .."éç\11\5é\20\3ç\11\3åã%\5åd\3ãä\17\5ã%\3ä\17\3â˛\3à˛\3á˛\3ÜÖ\17"
  .."\5Ü˛\3Ö\17\3Ñ˛\3É˛\3Ç\17B\5ÇS\3Å˛\3Äx\3\127~}\5\127˛\3~}\3}\30"
  .."\3|˛\3{\14\3z˛\3w˛\3v˛\3ut\12\5u\15\3u∏\1\0@⁄\4t\12\3t¿\4s\18"
  .."\3s@\4r˛\3q˛\3p˛\3onS\5oñ\3nm(\5nS\3m(\3l˛\3k\50\3j˛\3i\50\3"
  .."h˙\3gª\3f˛\3e˛\3d˛\3cb\30\5c˛\3b\0\16\5b\30\3a˛\3`˛\3_˛\3^Z\11"
  .."\5^\14\3\93d\3\92»\3\91Z\11\5\91\20\3Z\11\3Y˛\3X\20\3W˛\3V˛\3"
  System.VERA=System.VERA
  .."U\27\25\5U\50\3T˛\3S˛\3R˛\3Q}\3P˛\3O\20\3N˛\3M\1\45\5M˛\3Lª\3"
  .."K(\3JI\24\5J\55\3IC\18\5I\24\3HE\24\5H˛\3GC\18\5Gd\3FE\24\5F"
  .."ª\3E\24\3DC\18\5D\55\3CB\17\5C\18\3C∏\2@@\9\4BA\15\5B\17\3B∏"
  .."\2\0@\9\4A@\14\5A\15\3A∏\1¿@\9\4@?\12\5@\14\3@∏\1Ä@\9\4?\12\9"
  .."\5?\12\3?∏\1@@d\4>˛\3=\1\45\5=˙\3<˛\3;(\3:˛\3\57\17B\5\57d\3"
  .."\56\49\26\5\56K\3\55˛\3\54\45\20\5\54˛\3\53K\3\52\48\26\5\52"
  .."K\3\51\48\26\5\51˛\3\50\17B\5\50˛\3\49\45\20\5\49\26\3\48\26"
  .."\3\47\45\20\5\47\24\3\46\9\22\5\46ª\3\45,\19\5\45\20\3\45∏\2"
  .."Ä@\9\4,\16\17\5,\19\3,∏\2@@ñ\4+*%\5+˛\3*\9\22\5*%\3)\2:\5)˛\3"
  .."(˛\3'˛\3&\15\3%\22B\5%E\3$\15\3#˛\3\34\15\15\5\34˛\3! \45\5!"
  .."}\3 \45\3\31K\3\30\17B\5\30˛\3\29˛\3\28\27\25\5\28˛\3\27\0\16"
  .."\5\27\25\3\26˛\3\25˛\3\24˛\3\23\22B\5\23F\3\22\21\45\5\22B\3"
  .."\21\20\16\5\21\45\3\20\16\3\19\0\16\5\19\20\3\18\17B\5\18˛\3"
  .."\17\1\45\5\17B\3\16\15\15\5\16\17\3\16∏\2\0@\9\4\15\14\12\5\15"
  .."\15\3\15∏\1¿@\9\4\14\13\10\5\14\12\3\14∏\1Ä@\9\4\13\12\9\5\13"
  .."\10\3\13∏\1@¥\4\12\9\3\12∏\1\0@\55\4\11˛\3\10\9\22\5\10˛\3\9"
  .."\22\3\8\16\3\7˛\3\6\1\45\5\6˛\3\5\20\3\3\2:\5\3˙\3\2\1\45\5\2"
  ..":\3\1\0\16\5\1\45\3\0\16\3\1∏\1dÖç\1++++++++++++++++++++++++"
  .."++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  .."++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  .."+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\0"
  .."++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  .."++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  .."++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  .."+++++++++++\29\0∂\6\5\4\3\2\1\0, \16∞\2%Id∞@QX »Y!\45,∞\2%Id"
  .."∞@QX »Y!\45, \16\7 ∞\0P∞\13y ∏ˇˇPX\4\27\5Y∞\5\28∞\3%\8∞\4%#·"
  .." ∞\0P∞\13y ∏ˇˇPX\4\27\5Y∞\5\28∞\3%\8·\45,KPX ∏\1\23EDY!\45,∞"
  .."\2%E`D\45,KSX∞\2%∞\2%EDY!!\45,ED\45\0\2\0h˛ñ\4h\5§\0\3\0\7\0"
  .."\31º\0\4\1\20\0\0\0\6\1\20∂\1\8\5É\2\4\0\47ƒ‘Ï\49\0\16‘Ï‘Ï\48"
  .."\19\17!\17%!\17!h\4\0¸s\3\27¸Â˛ñ\7\14¯Úr\6)\0\0\2\2\4\0\0\2œ"
  .."\5’\0\5\0\9\0\31@\15\3á\6Ü\0à\8\4\3\7\1\3\6\0\10\16‘<Ï\50\57"
  .."\57\49\0\47‰¸Ï\48\1\51\17\3#\3\17\51\21#\2\4À\21°\21ÀÀ\5’˝q˛"
  System.VERA=System.VERA
  .."õ\1e˝∏˛\0\2\1R\3™\3\127\5’\0\3\0\7\0\29@\14\5\1â\4\0à\8\0\4\2"
  .."\6\4\4\8\16‘Ï‹Ï\49\0\16Ù<Ï\50\48\1\17#\17#\17#\17\3\127Æ—Æ\5"
  .."’˝’\2+˝’\2+\0\2\0\2\0\0\4Õ\5æ\0\27\0\31\0J@\48\28\23\7å\3\0\25"
  .."\5\1\30\21\9å\19\15\11\17\13\31\30\29\28\27\26\24\23\22\19\18"
  .."\17\16\15\14\13\12\10\9\8\5\4\3\2\1\0\26\6\20 \16‘Ã\23\57\49"
  .."\0\47<‘<<¸<<‘<<ƒ\50Ï\50\50\48\1\3\51\19\51\3\51\21!\3\51\21!"
  .."\3#\19#\3#\19!\53!\19!\53!\19\1#\3\51\2¨hıi†iÙ˛ÁT˙˛ﬂh†iˆiüh˛"
  .."˛\1)T˛ˆ\1\47h\1\8ıTˆ\5æ˛a\1ü˛aö˛≤ô˛b\1û˛b\1ûô\1Nö\1ü˝«˛≤\0\3"
  .."\0æ˛”\4Z\6\20\0\6\0\13\0\47\0d@\57\8($\0\7)\24\4%\20\47\16\23"
  .."\19\1%ã$é\31(è\30\20ã\19é\1è\14!\30\16\4\6$\8,\5\0\11\6\27\19"
  .."\5( \14\3\0\7\30\23\15\3\7\48\16‘\23<Ï\23\50¸<Ï\16¸‰Ó\49\0\47"
  .."∆\50ƒÓˆÓ\16Ó∆ˆÓ\17\18\57\17\57\17\18\23\57\17\18\57\48\1\17\54"
  .."\54\53\52&'\17\6\6\21\20\22\19#\3&&'\53\22\22\23\17&&\53\52\54"
  .."\55\53\51\23\22\22\23\21&&'\17\22\22\21\20\6\7\2¥n|pﬁhum‘d\1"
  .."f…bdÀc» ”ød\1O¢TU°PŒÿÈº\2D˛N\3td\93g—\1ù\4p^Vd˚¿\1\45\5\46)¥"
  ..">B\2\1 \31∂ñùª\14ÎÎ\5\30\26≠+\47\4˛Q\31¬ööŒ\9\0\0\5\0!\0\0\4"
  .."∞\5ò\0\11\0\26\0\30\0*\0\57\0V@\47\30\55\29(\34\28\15\27\3\9"
  .."í\15\34í\55ì(í\46ë\15ì\3í\24\28\27+\31\30\29\6\10\21\11\0\10"
  .."\12%\10\52\11\31\10+\12:\16ƒ‘Ï¸Ï\16Ó˛Ó\57\57\17\18\57\57\49\0"
  .."\47ÓÓˆÓ˛Ó\16Ó\17\57\17\57\17\18\57\18\57\48\1\20\22\51\50\54"
  .."\53\52&#\34\6\7\52\54\51\50\22\23\22\22\21\20\6#\34&\1'\1\23"
  .."%\20\22\51\50\54\53\52&#\34\6\7\52\54\51\50\22\23\22\22\21\20"
  .."\6#\34&\2∏iNMklLNiá∏Ü@s\46\46\50∫áà∂˛H#\4\18)¸\23iOMllMMká∏á"
  .."@u\45\45\49∫Üá∏\1?NjkMMljOáπ\48\46\47t?Ö∫∑\1\26`\1¢`ÂOikMMkj"
  .."Náπ\48\45\45uAÜπ∏\0\0\2\0\57ˇ„\4≈\5\0*\0\55\0≥@b\17\16\2\18"
  .."\15\23\12\13\12\14\23\13\13\12\45,\2\46+\23\0\1\0\50\51\52\53"
  .."\54\5\49\55\23\1\1\0B\55\12\9\6\1\5\7\15\49\13\24\0+\3\34\7\49"
  .."ó\18\34!%ó\30ñ\18ô\7\13\0(\1\7\6\3!\12\8\4\55+!\24(\27\15!\4"
  .."\19\8(\18!\27\8\13\16\27\46\18\21\56\16‹Ïƒ¸ƒ\16∆Ó\16Ó\17\57\17"
  .."\18\57\17\57\57\17\18\57\18\23\57\17\57\49\0\47∆‰ˆÓ÷Œ\16Ó\17"
  .."\18\23\57\17\18\57\17\23\57\48KSX\7\16\14Ì\17\23\57\7\16\14Ì"
  .."\17\23\57\7\16\5Ì\7\16\5Ì\17\23\57Y\34\1\1\54\54\53\52''\51\21"
  System.VERA=System.VERA
  .."\20\6\7\23#'\6\6#\34\0\53\52\54\55&&\53\52\54\51\50\22\23\21"
  .."&&#\34\6\21\20\22\7\6\6\21\20\22\51\50\54\55\54\54\55\2#\1†'"
  .."&\3\1§JK™’NS∫jÿ˛Êäã\50\48«≠AÉF;}Eap:\54\92\91»õ*\92,\27#\16\3"
  .."ã˝—\49ñh F\7'°ÛXÂmFD\1\13ÃâÍdHäGñÆ\24\23∑'%\91M;ÅœI£\92ó«\24"
  .."\23\15\23\13\0\1\2\16\3™\2æ\5’\0\3\0\18∑\1\0à\4\0\4\2\4\16‘Ï"
  .."\49\0\16Ùƒ\48\1\17#\17\2æÆ\5’˝’\2+\0\0\1\1™˛Ú\3u\6\18\0\13\0"
  .."\31@\15\6ú\0õ\14\13\7\0\3\18\6\0\24\10\14\16‘Ï\50Ï\17\57\57\49"
  .."\0\16¸Ï\48\1\6\2\21\20\18\23#&\2\53\52\18\55\3uÖÉÉÖ†óîîó\6\18"
  .."‰˛;ÊÂ˛:ÊÓ\1√‡ﬂ\1ƒÏ\0\1\1\92˛Ú\3'\6\18\0\13\0\31@\15\7ú\0õ\14"
  .."\7\1\11\8\0\24\4\18\11\14\16‘¸Ï\50\17\57\57\49\0\16¸Ï\48\1\51"
  .."\22\18\21\20\2\7#\54\18\53\52\2\1\92†óîîó†ÖÉÉ\6\18Ï˛<ﬂ·˛<ÏË\1"
  .."∆„‰\1∆\0\0\1\0¶\2J\4+\5\0\17\0N@,\16\13\11\0\4\12\9\7\4\2\4"
  .."\8\3ù\5\17\12ù\10\1\14ñ\18\8\12\10\3\9\6\17\3\1\3\2\0\25\15\4"
  .."\11\9\25\13\6\18\16‘<Ï\50‹<Ï\50\23\57\17\18\23\57\49\0\16Ù‘<"
  .."Ï\50ƒÏ\50\23\57\18\23\57\48\1\5\5\7%\17#\17\5'%%\55\5\17\51\17"
  .."%\4+˛ö\1f\57˛∞s˛∞\57\1f˛ö\57\1Ps\1P\4ﬂ¬√bÀ˛á\1yÀb√¬cÀ\1y˛áÀ\0"
  .."\1\0X\0q\4y\4ì\0\11\0'@\20\0°\9\1†\5°\7\3\12\2\26\4\0\28\8\26"
  .."\10\6\12\16‘<Ï¸<Ï\49\0\16‘<Ï¸<Ï\48\1\17!\21!\17#\17!\53!\17\2"
  .."º\1Ω˛C®˛D\1º\4ì˛D™˛D\1º™\1º\0\1\1ì˛·\2Ú\1\47\0\5\0\24@\11\3£"
  .."\0¢\6\3\4\1\29\0\6\16‘Ï‘Ã\49\0\16¸Ï\48\1\51\21\3#\19\1ˆ¸≈öc\1"
  .."\47œ˛Å\1\127\0\0\1\1d\1ﬂ\3m\2É\0\3\0\17∂\0†\2\4\1\0\4\16‘ƒ\49"
  .."\0\16‘Ï\48\1!\21!\1d\2\9˝˜\2É§\0\1\1È\0\0\2Â\1\49\0\3\0\16∂\0"
  .."¢\2\1\29\0\4\16‘Ï\49\0\47Ï\48\1\51\17#\1È¸¸\1\49˛œ\0\1\0fˇB\4"
  .."\55\5’\0\3\0\24@\11\2\0à\4\1\30\0\2\30\3\4\16‘Ï‘Ï\49\0\16Ùƒ\48"
  .."\1\51\1#\3yæ¸Óø\5’˘m\0\3\0Öˇ„\4L\5\0\11\0\23\0#\1\10@\26\3•"
  .."\9\18ó\30\12ó\24ñ\30ô$\21\30\27\6!\0\27\34\15\30!\31$\16¸ÏÏ‘"
  .."Ï\16Ó\49\0\16‰ÙÏ\16Ó‘Ó\48@÷\47\0\47\1\47\2\47\3\47\4\47\5\47"
  .."\6\47\7\47\8\47\9\47\10\47\11?\0?\1?\2?\3?\4?\5?\6?\7?\8?\9?"
  .."\10?\11O\0O\1O\2O\10O\11_\0_\1_\2_\10_\11ü\0ü\1ü\2ü\3ü\4ü\5ü"
  .."\6ü\7ü\8ü\9ü\10ü\11Ø\0Ø\1Ø\2Ø\3Ø\4Ø\5Ø\6Ø\7Ø\8Ø\9Ø\10Ø\11ø\0"
  .."ø\1ø\2ø\3ø\4ø\5ø\6ø\7ø\8ø\9ø\10ø\11F\47\0\47\1\47\2\47\3\47\4"
  .."\47\5\47\6\47\7\47\8\47\9\47\10\47\11_\0_\1_\2_\3_\4_\5_\6_\7"
  System.VERA=System.VERA
  .."_\8_\9_\10_\11ø\0ø\1ø\2ø\3ø\4ø\5ø\6ø\7ø\8ø\9ø\10ø\11$\93\1\93"
  .."\1\52\54\51\50\22\21\20\6#\34&\19\34\2\17\16\18\51\50\18\17\16"
  .."\2'\50\18\17\16\2#\34\2\17\16\18\1„M\54\56PO\57\56KÖçããçéããé"
  .."ÔııÔÔÙÙ\2Ó\55PP\55\56NL\2ú˛–˛…˛ ˛–\1\48\1\54\1\55\1\48†˛x˛Å˛"
  .."Ç˛x\1à\1~\1\127\1à\0\1\0ˆ\0\0\4F\5’\0\10\0&@\20\3ó\4\2ó\5à\7"
  .."\0ó\9\8#\6\30\3\0#\1\11\16‘Ïƒ¸Ï\49\0\47Ï\50ÙÏ‘Ï\48%!\17\5\53"
  .."%\51\17!\21!\1\14\1:˛Æ\1P \1\54¸»™\4uL∏J˙’™\0\0\1\0ò\0\0\4#\5"
  .."\0\28\0Q@)\0\28%\5\6\5\24\25\26\3\23\27%\6\6\5B\16\17ß\13ó\20"
  .."ñ\4\0ó\2\0\16\10\2\1\10\30\23\34\16\3$\29\16¸ƒ¸Ï¿¿\17\18\57\49"
  .."\0\47Ï\50ÙÏÙÃ\48KSX\7\16\5Ì\17\23\57\7\16\5Ì\23\50Y\34%!\21!"
  .."\53\54\0\55\54\54\53\52&#\34\6\7\53\54\54\51\50\4\21\20\6\7\6"
  .."\6\1u\2Æ¸uª\1\24\53dFìÄ\91»pg«a€\1\11Yd\56’™™™≈\1\46>zóO}éBC"
  .."Ã\49\50ÈΩ`¿tAÊ\0\0\1\0âˇ„\4\55\5\0(\0G@)\0\19ó\21\10ã\9¶\13"
  .."ó\6\31ã ¶\28ó#ñ\6ô\21©)\22\19\0\3\20\25\30&\16\30\3\34\31\20"
  .."\9\31)\16¸ƒƒ¸Ï‘Ï\17\23\57\49\0\16Ï‰ÙÏÙÏ\16ÓˆÓ\16Ó\57\48\1\22"
  .."\22\21\20\4#\34&'\53\22\22\51\50\54\53\52&##\53\51\50\54\53\52"
  .."&#\34\6\7\53\54\54\51\50\4\21\20\6\3\8ìú˛Îıg÷gf∆b¶≤≤òööãúëÜY"
  .."æhyΩI⁄\1\5â\3\31'«ïŒÎ&$…\53\52ñçÇô¶zms{((∫  €µ{§\0\0\2\0f\0\0"
  .."\4o\5’\0\2\0\13\0B@\31\1\13\3\13\0\3\3\13B\0\3\11\7ó\5\1\3à\9"
  .."\1\12\10\0\30\8\4\6\15\12$\14\16¸¸‘<Ï\50\17\57\49\0\47‰‘<Ï\50"
  .."\18\57\48KSX\7\16\4…\7\16\5…Y\34\1\1!\3\51\17\51\21#\17#\17!"
  .."\53\2ﬂ˛)\1◊!Í««…˝á\5\29¸Î\3Õ¸\51§˛ú\1dø\0\0\1\0èˇ„\4\45\5’\0"
  .."\29\0=@\34\4\7\29\26ó\7\17ã\16é\20ó\13\2ó\0à\13ô\7™\30\3\30\0"
  .."\23\30\1\10\34\0\16\31\30\16¸ƒ¸ƒÏ\16Ó\49\0\16‰‰ÙÏ\16ÓˆÓ\16˛ƒ"
  .."\18\57\48\19!\21!\17\54\54\51\50\0\21\20\0#\34&'\53\22\22\51"
  .."\50\54\53\52&#\34\6\7œ\2Ù˝ƒ+W,Ë\1\16˛„˜w≈N\92∫aßµªßQöF\5’™˛ë"
  .."\16\15˛ÓÍÏ˛  Õ\50\49∞¢†≤%%\0\2\0Öˇ„\4L\5\0\24\0$\0=@#\7\31"
  .."\25ó\10\31ó\16\10´\4\1ã\0é\4ó\22ñ\16ô%\34\30\0&\13\34\7\6\28"
  .."\1\19\31%\16¸ÏÏ¸‰Ï\49\0\16‰ÙÏÙÏ\16Â\16Ó\16Ó\17\57\48\1\21&&#"
  .."\34\2\17\54\54\51\50\18\21\20\2# \2\17\16\0!\50\22\1\34\6\21"
  .."\20\22\51\50\54\53\52&\3ﬂ?éM¿∆\48™nÿÌÙ›˛¸Ú\1#\1\20Jî˛›ÅîîÅÜà"
  .."à\5¥∫%'˛ﬂ˛Ádk˛˜ÛÚ˛ˆ\1u\1ë\1z\1ç\31˝l∫§§∫±≠Æ∞\0\1\0ã\0\0\4\55"
  System.VERA=System.VERA
  .."\5’\0\6\0\53@\25\5%\2\3\2\3%\4\5\4B\5ó\0à\3\5\3\1\4\1\34\0\31"
  .."\7\16¸Ïƒ\17\57\57\49\0\47ÙÏ\48KSX\7\16\5Ì\7\16\5ÌY\34\19!\21"
  .."\1#\1!ã\3¨˝Í”\2\8˝\53\5’V˙Å\5+\0\0\3\0Éˇ„\4N\5\0\11\0#\0\47"
  .."\0C@%\24\12\0ó'\6ó\30\45ó\18ñ\30ô'©\48\24\12$*\30\21$\30\15\9"
  .."\30\21\27\34\3\30\15!\31\48\16¸ƒÏ¸ƒÏ\16Ó\16Ó\17\57\57\49\0\16"
  .."Ï‰ÙÏ\16Ó\16Ó\57\57\48\1\34\6\21\20\22\51\50\54\53\52&%&&\53\52"
  .."\54\51\50\22\21\20\6\7\22\22\21\20\4#\34$\53\52\54\19\20\22\51"
  .."\50\54\53\52&#\34\6\2háìïÖàìï˛ ÅëÚ–—ÚëÅñü˛˛‰‰˛ˇüMÄyzÄ\127{yÄ"
  .."\2≈óääôóåâòT!¥\127≤——≤\127¥!!»ü ‰„…†…\1bx~~xzÄÅ\0\0\2\0\127ˇ"
  .."„\4F\5\0\11\0$\0;@\34\19\6\0ó\22´\16\13ã\12é\16ó\34\6ó\28ñ\34"
  .."ô%\19\6\3\1\31\34\9\30\12&\25\31%\16¸‰Ï¸ÏÏ\49\0\16‰ÙÏ\16ÓˆÓ\16"
  .."ıÓ\17\57\48\1\50\54\53\52&#\34\6\21\20\22\3\53\22\22\51\50\18"
  .."\17\6\6#\34\2\53\52\18\51 \18\17\16\0!\34&\2TÅììÅÜàá·?éM¿≈\47"
  .."™nÿÌÛﬁ\1\4Ú˛›˛ÎIî\2ñ∫§§∫±≠Æ∞˝â∫%'\1!\1\25dk\1\10ÙÒ\1\9˛ä˛o˛á"
  .."˛s\31\0\0\2\1È\0\0\2Â\4'\0\3\0\7\0\27@\13\2¢\0¨\4¢\6\5\1\29\4"
  .."\0\8\16‘<Ï\50\49\0\47ÏÙÏ\48\1\51\17#\17\51\17#\1È¸¸¸¸\4'˛—˛\57"
  .."˛œ\0\0\2\1ì˛·\2Ú\4'\0\5\0\9\0%@\19\8¢\6\3£\0¢\6¨\10\3\4\0\29"
  .."\1\7\29\6\10\16‘¸‘¸‘Ã\49\0\16‰¸Ï\16Ó\48\1\51\21\3#\19\3\51\17"
  .."#\1ˆ¸≈öc\13¸¸\1\47œ˛Å\1\127\3«˛—\0\0\1\0X\0ç\4y\4w\0\6\0!@\18"
  .."\5\4\2\1\0\5\3Æ\6≠\7\1\2\0(\4'\7\16¸Ï\50\57\49\0\16ÙÏ\23\57\48"
  .."\9\2\21\1\53\1\4y¸Æ\3R˚ﬂ\4!\3¡˛¿˛√∑\1¢¶\1¢\0\0\2\0X\1`\4y\3¢"
  .."\0\3\0\7\0\27@\12\4†\6\2†\0\8\5\1\4\0\8\16‘<ƒ\50\49\0\16‘Ï‘Ï"
  .."\48\19!\21!\17!\21!X\4!˚ﬂ\4!˚ﬂ\2\12¨\2B™\0\1\0X\0ç\4y\4w\0\6"
  .."\0!@\18\6\5\3\2\0\5\4Æ\1≠\7\6\2(\4\0'\7\16¸<Ï\57\49\0\16ÙÏ\23"
  .."\57\48\19\53\1\21\1\53\1X\4!˚ﬂ\3R\3¡∂˛^¶˛^∑\1=\0\2\0Ù\0\0\4\16"
  .."\5\0\30\0\34\0{@B\11\10\9\8\7\5\12\6%\25\26\25\3\4\2\2\5%\26"
  .."\26\25B\29\26\5\2\4\6\25\15\0\31\16ã\15ç\12ó\19ñ\31Ü!\6 \25\22"
  .."\9\5\1\0\26 \9\0\3\1\9)\22\15\1 \3\31#\16‘Ïƒ‘‘Ï\16Ó\17\18\57"
  .."\17\18\57\17\18\57\18\57\49\0\47Óˆ˛ÙÓ\16Õ\17\57\57\23\57\48K"
  .."SX\7\16\4Ì\17\23\57\7\16\4Ì\17\23\57Y\34\1#\53\52\54\55\55\54"
  .."\54\53\52&#\34\6\7\53\54\54\51\50\22\21\20\6\7\7\6\6\21\21\3"
  .."\51\21#\2¨æ=TZ>\47ÉmN≤b^øh∫›C^XE&≈ÀÀ\1ëöbâRY;X\49YnEDº\57\56"
  System.VERA=System.VERA
  .."¿°LÉ\92VBT=\47˛Ú˛\0\2\0\27˛¡\4ö\5s\0\11\0\52\0p@\49(+$\26\23"
  .."\3\14\12\9\27\52\3Ø\23\9Ø\12\17'$Ø+\23\30Ø\49+\53'\13\6(\12\0"
  .."\6+\20\0\26\13\46\12\20!+\12\45\46\53\16‹Ï¸ƒ\16˛<ƒ\16Ó\17\18"
  .."\57\17\18\57\49\0\16ƒ‘¸ƒ\16˛ƒ’ƒÓ\16Ó\57\57\17\18\57\17\18\57"
  .."\17\18\57\48@\13Ä\5Ä\6Ä\7Ä\19Ä\20Ä\21\6\1\93\1\52&#\34\6\21\20"
  .."\22\51\50\54\19#\53\14\1#\34&\53\52\54\51\50\22\23\53\52&#\34"
  .."\0\17\16\0!\50\54\55\23\14\1# \0\17\16\0!\50\18\21\4\14ÄkkÅÅ"
  .."kkÄåê%ÉR°””°PÜ$∞ëˆ˛›\1J\1\18\54l\57\48?{:˛õ˛\93\1x\1<—˙\2!Åõ"
  .."õÅÇõõ˛Ëo?DÚººÚF=?úæ˛Å˛π˛∑˛z\20\21á\25\24\1“\1å\1Ü\1Œ˛ˆ‡\0\2\0"
  .."%\0\0\4¨\5’\0\2\0\10\0ò@A\0%\1\0\4\5\4\2%\5\4\7%\5\4\6%\5\5\4"
  .."\9%\3\10\8%\3\10\1%\10\3\10\0%\2\0\3\3\10B\0\3\7ó\1∞\3à\9\5\9"
  .."\8\7\6\4\3\2\1\0\9\5\47\10\11\16‹Ï\23\57\49\0\47<‰¸Ï\18\57\48"
  .."KSX\7\16\8Ì\7\16\5Ì\7\5Ì\7\5Ì\7\16\5Ì\7\5Ì\7\5Ì\7\16\8ÌY\34≤"
  .."\7\3\1\1\93@\26\10\0\15\0è\0è\0\4\3\1\11\2\4\3\12\4\9\7\6\8Ü"
  .."\1â\2\8\93\0\93\1\3!\1\51\1#\3!\3#\2h’\1™˛±ı\1…—n˝ıl—\5#˝\4\3"
  .."Æ˙+\1Ö˛{\0\0\3\0¶\0\0\4q\5’\0\8\0\17\0 \0=@#\25\0ó\10\9ó\18à"
  .."\1ó\10±\31\17\11\25\31\19\8\2\5\0\14\30\22\5\50\28\49\9\0\30"
  .."\18\48!\16¸Ï\50¸Ï‘Ï\17\23\57\57\57\49\0\47ÏÏÙÏ\16Ó\57\48\1\17"
  .."\51\50\54\53\52&#\3\17\51\50\54\53\52&#%!\50\22\21\20\6\7\22"
  .."\22\21\20\4!!\1qÔ∞ñû®ÔÎíÉÅî˛J\1∫Â¯ÉÉìß˛ˆ˛˘˛F\2…˝›{çíâ\2f˛>p}"
  .."qd¶∆µâû\20\22œ†Àœ\0\1\0ãˇ„\4\49\5\0\25\0\46@\26\25≥\0≤\22ó\3"
  .."\13≥\12≤\16ó\9ñ\3ô\26\19\50\12\0\49\6\48\26\16¸Ï\50Ï\49\0\16"
  .."‰ÙÏÙÏ\16ÓˆÓ\48%\6\6# \0\17\16\0!\50\22\23\21&&#\34\2\17\16\18"
  .."\51\50\54\55\4\49M¢\91˛·˛√\1?\1\29\91¢MJ™V≈ƒƒ≈X©I\53))\1ñ\1p"
  .."\1n\1ô))œ=@˛–˛Õ˛Œ˛–@=\0\2\0â\0\0\4R\5’\0\8\0\17\0(@\21\6ó\9à"
  .."\0ó\15\6\0\15\9\7\3\50\12\49\7\30\16\48\18\16¸Ï¸Ï\17\57\57\57"
  .."\57\49\0\47ÏÙÏ\48%\50\54\17\16&!#\17\19 \0\17\16\0!!\17\1¥ˇ "
  .."…ˇ\0`d\1V\1D˛º˛™˛—¶˚\1H\1K˚˚w\5\47˛î˛Ä˛Ç˛ï\5’\0\1\0≈\0\0\4N\5"
  .."’\0\11\0)@\22\6ó\4\2ó\0à\8ó\4±\10\1\5\9\49\7\3\30\0\51\12\16"
  .."¸Ï\50¸ƒƒ\49\0\47ÏÏÙÏ\16Ó\48\19!\21!\17!\21!\17!\21!≈\3v˝T\2é"
  .."˝r\2ø¸w\5’™˛F™˝„™\0\0\1\0È\0\0\4X\5’\0\9\0$@\19\6ó\4\2ó\0à\4"
  .."±\8\5\1\49\7\3\30\0\52\10\16¸Ï\50¸ƒ\49\0\47ÏÙÏ\16Ó\48\19!\21"
  System.VERA=System.VERA
  .."!\17!\21!\17#È\3o˝\92\2e˝õÀ\5’™˛H™˝\55\0\1\0fˇ„\4P\5\0\29\0"
  .."<@!\25\26\0\22\3\26ó\28\22ó\3\13≥\12≤\16ó\9ñ\3ô\30\27\25\30\12"
  .."\0\54\19\50\6\53\30\16¸Ï¸ƒ¸ƒ\49\0\16‰ÙÏÙÏ\16˛‘Ó\17\18\57\17\57"
  .."\48%\6\6# \0\17\16\0!\50\22\23\21&&#\34\2\17\16\18\51\50\54\55"
  .."\17#\53!\4PQÀv˛‰˛ƒ\1@\1\29^¨PQ™_≈≈ø∆Ce)Ÿ\1ö{KM\1ó\1o\1n\1ô\53"
  .."\54œMI˛œ˛Œ˛…˛’\31!\1ë¶\0\1\0â\0\0\4H\5’\0\11\0&@\20\8ó\2±\4\0"
  .."à\10\6\7\3\30\5\49\9\1\30\0\48\12\16¸Ï\50¸Ï\50\49\0\47<‰\50¸"
  .."Ï\48\19\51\17!\17\51\17#\17!\17#âÀ\2)ÀÀ˝◊À\5’˝ú\2d˙+\2«˝\57\0"
  .."\0\1\0…\0\0\4\6\5’\0\11\0%@\19\10\2ó\0à\8\4ó\6\5\1\55\3\30\7"
  .."\0\55\9\12\16‘Ï\50¸Ï\50\49\0\47Ï\50ÙÏ\50\48\19!\21!\17!\21!\53"
  .."!\17!…\3=˛«\1\57¸√\1\57˛«\5’™˚\127™™\4Å\0\0\1\0mˇ„\3º\5’\0\17"
  .."\0,@\23\12\7\8\1\0≤\4ó\15\8ó\10à\15ô\18\9\7\30\11\0\53\18\16"
  .."¸‘¸ƒ\49\0\16‰ÙÏ\16ÓˆŒ\17\57\57\48\55\53\22\22\51\50\54\53\17"
  .."!\53!\17\16\6#\34&m\91¬hèq˛É\2G”˜`æ=ÏQQïÀ\3D™¸\18˛ÊÍ,\0\0\1\0"
  .."â\0\0\4…\5’\0\11\0ó@!\8%\9\8\5\6\5\7%\6\5B\8\5\2\3\3\0¥\10\6"
  .."\8\5\4\3\6\1\9\1\30\0\48\12\16¸Ï\50\16¿\23\57\49\0\47<Ï\50\23"
  .."\57\48KSX\7\5Ì\7\16\8ÌY\34≤\8\4\1\1\93@L\7\5\22\5\23\8&\5&\8"
  .."\54\2F\2U\2W\8X\9d\2z\5y\8{\9\14\2\3\1\4\7\5\0\6\2\7\22\5\23"
  .."\8'\5,\6+\7&\8:\3I\3G\6G\7\91\3W\5X\6X\7W\8k\3z\3x\7\23\93\0"
  .."\93\19\51\17\1\51\9\1#\1\7\17#âÀ\2wÌ˝ª\2VÙ˛\25öÀ\5’˝h\2ò˝û¸ç"
  .."\2Ï§˝∏\0\1\0◊\0\0\4s\5’\0\5\0\24@\12\2ó\0à\4\1\30\3\49\0\52\6"
  .."\16¸ÏÏ\49\0\47‰Ï\48\19\51\17!\21!◊À\2—¸d\5’˙’™\0\0\1\0V\0\0\4"
  .."y\5’\0\12\0Ö@,\8\2\3\2\7\3\3\2\10\1\2\1\9\2\2\1B\10\7\2\3\0\8"
  .."\3\0¥\11\5\9\8\3\2\1\5\10\6\6\4\47\10\6\0\48\13\16¸Ï¸Ï\17\23"
  .."\57\49\0\47<Ï\50ƒ\17\23\57\48KSX\7\16\5…\7\16\4…\7\16\4…\7\16"
  .."\5…Y\34≤\15\10\1\0\93@$\5\8\10\9\23\1\24\3\23\8\24\9&\1)\3&\8"
  ..")\9\54\1\57\3\54\8\56\9\14\15\7\15\7\15\10\3\93\1\93\19!\9\1"
  .."!\17#\17\1#\1\17#V\1\14\1\2\1\4\1\15ª˛ˆô˛ı∫\5’˝\8\2¯˙+\5'¸Ì\3"
  .."\19˙Ÿ\0\1\0ã\0\0\4F\5’\0\9\0m@\28\7\1\2\1\2\6\7\6B\7\2\3\0¥\8"
  .."\5\6\1\7\2\17\4\49\7\17\0\48\10\16¸Ï¸Ï\17\57\57\49\0\47<Ï\50"
  .."\57\57\48KSX\7\16\4…\7\16\4…Y\34≤\23\1\1\1\93@&\23\2\24\7)\2"
  .."&\7\56\7W\2d\2j\7u\2z\7\10\24\6&\1)\6F\1I\6W\1g\1h\6\8\93\0\93"
  System.VERA=System.VERA
  .."\19!\1\17\51\17!\1\17#ã\1\0\1¯√ˇ\0˛\8√\5’˚\51\4Õ˙+\4Õ˚\51\0\2"
  .."\0uˇ„\4\92\5\0\11\0\23\0#@\19\9ó\15\3ó\21ñ\15ô\24\0\50\12\54"
  .."\6\50\18\53\24\16¸Ï¸Ï\49\0\16‰ÙÏ\16Ó\48\1\16\2#\34\2\17\16\18"
  .."\51\50\18\19\16\2#\34\2\17\16\18\51\50\18\3âáöôááôöá”˜˝˝ˆ˜¸˝"
  .."˜\2È\1I\1\26˛Ê˛∑˛∏˛Ê\1\25\1I˛z˛Ä\1~\1à\1á\1Ä˛Ä\0\2\0≈\0\0\4u"
  .."\5’\0\8\0\19\0+@\24\1ó\16\0ó\9à\18\16\10\8\2\4\0\5\50\13\56\17"
  .."\0\30\9\51\20\16¸Ï\50¸Ï\17\23\57\49\0\47ÙÏ‘Ï\48\1\17\51\50\54"
  .."\53\52&#%!\50\4\21\20\4##\17#\1èÍåùúç˛L\1¥˙\1\2˛ˇ˚Í \5\47˝œî"
  .."ÖÖì¶„€›‚˝®\0\0\2\0u˛Ú\4\92\5\0\17\0\29\0=@ \0\30\16\17\15\27"
  .."ó\3\21ó\9ñ\3ô\17\30\17\24\16\12\15\0\24\18\50\12\54\24\50\6\53"
  .."\30\16¸Ï¸Ï\17\57\57\17\57\17\57\49\0\16ƒ‰ÙÏ\16Ó\57\18\57\18\57"
  .."\48\5\34\6#\34\2\17\16\18\51\50\18\17\16\2\7\23\7\19\16\2#\34"
  .."\2\17\16\18\51\50\18\2è\7\26\8˙˜˜¸˝˜âã»ó\16áöôááôöá\27\2\1Ä\1"
  .."Ü\1á\1Ä˛Ä˛y˛⁄˛ôHæd\3˜\1I\1\26˛Ê˛∑˛∏˛Ê\1\25\0\2\0è\0\0\4—\5’\0"
  .."\19\0\28\0j@\56\9\8\7\3\10\6%\3\4\3\5%\4\4\3B\6\4\0\21\3\4\21"
  .."ó\9\20ó\13à\11\4\5\17\22\9\6\3\10\3\17\0\28\14\3\10\25\50\4\17"
  .."\49\20\10\30\12\48\29\16¸Ï\50¸ƒÏ\17\23\57\17\57\17\23\57\17\57"
  .."\49\0\47<ÙÏ‘Ï\18\57\18\57\18\57\48KSX\7\16\5Ì\7\16\14Ì\17\23"
  .."\57Y\34\1\22\22\23\19#\3&&##\17#\17!\50\4\21\20\6\1\17\51\50"
  .."\54\53\52&#\2¯NnRÀŸ≤M{c¡À\1†ˆ\1\6°˝–›ëéóê\2¡\20o¶˛h\1y°\93˝â"
  .."\5’ﬁ“îª\2Y˝ÓÇÜÅâ\0\1\0ãˇ„\4J\5\0'\0Ñ@=\13\12\2\14\11%\30\31"
  .."\30\8\9\2\7\10%\31\31\30B\10\11\30\31\4\1\21≥\20ß\24ó\17\1≥\0"
  .."ß\4ó%ñ\17ô(\30\10\11\31\27\7\0&\27\57\14\49\20\7\57\34\48(\16"
  .."¸Ïƒ¸Ï‰\17\18\57\57\57\57\49\0\16‰ÙÏÙÏ\16ÓˆÓ\17\23\57\48KSX\7"
  .."\16\14Ì\17\23\57\7\16\14Ì\17\23\57Y\34≤\8\2\1\1\93@\10\7\0\7"
  .."\1\7\2\3\7\2\1\93\0\93\1\21\46\1#\34\6\21\20\22\31\1\30\1\21"
  .."\20\4#\34&'\53\30\1\51\50\54\53\52&\47\1\46\1\53\52$\51\50\22"
  .."\3Ù\92π^è¶mïj“¿˛¯¸i‘ksÕhô™uël–º\1\13ﬂVæ\5¢Õ;<Öqch#\24\49“µ’‡"
  .."\45\45◊IDâ{pv \25\47æ†»Ò'\0\1\0\47\0\0\4¢\5’\0\7\0\28@\14\6\2"
  .."ó\0à\4\1:\3\30\0:\5\8\16‘Ï¸Ï\49\0\47ÙÏ\50\48\19!\21!\17#\17!"
  .."\47\4s˛\45À˛+\5’™˙’\5+\0\0\1\0ìˇ„\4=\5’\0\30\0,@\24\15\3\19\16"
  .."\0\3\1\9ó\25ô\17\1à\31\15\30\18\49\2\30\0\48\31\16¸Ï¸Ï\49\0\16"
  System.VERA=System.VERA
  .."‰\50ÙÏ\17\23\57\57\57\48\19\17\51\17\20\22\23\22\22\51\50\54"
  .."\55\54\54\53\53\17\51\17\20\6\7\6\6#\34&'&&ìÀ\12\15 yVWx!\15"
  .."\12 \57FB™ji™CE:\2=\3ò¸\12m\93\25;<<;\25\92l^\3ò¸hÂ¡?;::;>≈\0"
  .."\1\0\57\0\0\4ò\5’\0\6\0L@)\1%\2\3\2\0%\6\0\3\3\2\0%\1\0\4\5\4"
  .."\6%\5\5\4B\0\5\1¥\3\6\4\3\1\0\5\2\47\5\48\7\16¸Ï\23\57\49\0\47"
  .."Ï\50\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5ÌY\34%\1\51\1#\1"
  .."\51\2h\1_—˛Kı˛K—™\5+˙+\5’\0\0\1\0\0\0\0\4—\5’\0\12\0·@D\5\6\5"
  .."\9\10\9\4\10\9\3\10\11\10\2\1\2\11\11\10\6%\7\8\7\5%\4\5\8\8"
  .."\7\2%\3\2\12\0\12\1%\0\12B\10\5\2\3\8\3\6\0¥\11\8\12\11\10\9"
  .."\8\6\5\4\3\2\1\11\7\0\47Ã\23\57\49\0\47<¸<ƒ\17\23\57\48KSX\7"
  .."\5Ì\7\16\8Ì\7\16\8Ì\7\16\5Ì\7\16\8…\7\16\5…\7\5…\7\16\8…Y\34"
  .."≤\24\9\1\1\93@^\31\3\31\4\31\10\47\3\47\4+\10?\3?\4\56\10Z\2"
  .."Z\5\11\23\11&\2*\3%\4*\5(\8+\9%\11&\12\53\2:\3\53\4:\5;\8:\9"
  .."\52\11\54\12T\0T\1Z\2X\3W\4V\5\91\6\91\7R\8W\9X\11\93\12g\8h"
  .."\12y\3v\4y\9v\11#\93\0\93\17\51\27\1\51\27\1\51\3#\11\1#≈è™”"
  .."¨è≈ﬂøÀ ø\5’˚D\3\34¸‹\4æ˙+\3w¸â\0\1\0\18\0\0\4æ\5’\0\11\0∆@K\9"
  .."%\10\11\10\8%\7\8\11\11\10\8%\9\8\5\6\5\7%\6\6\5\3%\4\5\4\2%"
  .."\1\2\5\5\4\2%\3\2\11\0\11\1%\0\0\11B\11\8\5\2\4\3\0¥\9\6\11\8"
  .."\7\5\2\5\0\4;\6\47\0;\10\48\12\16¸‰¸‰\17\23\57\49\0\47<Ï\50\23"
  .."\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5Ì\7\16\5Ì\7\16\8Ì\7\16"
  .."\8Ì\7\16\5ÌY\34≤\55\2\1\0\93@\56\13\5\4\11\24\5'\1(\3)\5&\11"
  .."X\11x\2y\5w\11\11\0\2\0\2\15\8\15\8\20\2\26\8!\2%\5+\8%\11\53"
  .."\2U\2Y\8X\11e\2s\2\16\93\1\93\19\51\9\1\51\9\1#\9\1#\1VŸ\1H\1"
  .."NŸ˛A\1ﬂŸ˛í˛u⁄\1Ù\5’˝Õ\2\51˝B¸È\2É˝}\3\23\0\0\1\0%\0\0\4¨\5’\0"
  .."\8\0Y@\46\3%\4\5\4\2%\1\2\5\5\4\2%\3\2\8\0\8\1%\0\0\8B\2\3\0"
  .."¥\6\2\7\3\5\4\1\7\0\4<\5\30\0<\7\9\16‘Ï¸Ï\17\18\57\17\18\57\17"
  .."\57\49\0\47Ï\50\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5ÌY\34"
  .."\19\51\1\1\51\1\17#\17%◊\1l\1kŸ˛!À\5’˝m\2ì¸…˝b\2û\0\1\0ú\0\0"
  .."\4ë\5’\0\9\0E@\28\8%\2\3\2\3%\7\8\7B\8ó\0à\3ó\5\8\3\0\1\4\47"
  .."\0\6\48\10\16¸ƒ¸ƒ\17\57\57\49\0\47ÏÙÏ\48KSX\7\16\5Ì\7\16\5ÌY"
  .."\34≤\8\8\1\1\93≤\7\3\1\93\19!\21\1!\21!\53\1!≤\3…¸Ù\3\34¸\11"
  .."\2˜˝\31\5’ö˚o™ö\4ë\0\0\1\1œ˛Ú\3w\6\20\0\7\0\30@\15\4∂\6∑\2∂\0"
  System.VERA=System.VERA
  .."µ\8\5\1\3=\0\8\16‘¸ƒ\50\49\0\16¸ÏÙÏ\48\1!\21#\17\51\21!\1œ\1"
  .."®˛X\6\20è˘¸è\0\1\0fˇB\4\55\5’\0\3\0\24@\11\1\0à\4\1\30\2\0"
  .."\30\3\4\16‘Ï‘Ï\49\0\16Ùƒ\48\1\1#\1\1%\3\18æ¸Ì\5’˘m\6ì\0\0\1\1"
  .."Z˛Ú\3\2\6\20\0\7\0\30@\15\3∂\1∑\5∂\0µ\8\0=\6\2\4\8\16‘ƒ\50Ï\49"
  .."\0\16¸ÏÙÏ\48\1\17!\53\51\17#\53\3\2˛X\6\20¯ﬁè\6\4è\0\1\0H\3"
  .."®\4â\5’\0\6\0\24@\10\3\4\1\0à\7\3\1\5\7\16‘Ã\57\49\0\16ÙÃ\50"
  .."\57\48\1\1#\1\1#\1\2¡\1»≤˛ë˛í≤\1»\5’˝”\1ã˛u\2\45\0\0\1\0\0˛\29"
  .."\4\0˛m\0\3\0\15µ\0∏\1\4\0\2\47Ã\49\0\16‘Ï\48\1\21!\53\4\0¸\0"
  .."˛mPP\0\0\1\1\23\4Ó\2ˆ\6f\0\3\0\49@\9\1∫\0π\4\1<\3\4\16‘Ï\49\0"
  .."\16ÙÏ\48\0K∞\9TK∞\14T\91XΩ\0\4ˇ¿\0\1\0\4\0\4\0@\56\17\55\56Y"
  .."\9\1#\1\1›\1\25ö˛ª\6f˛à\1x\0\2\0Öˇ„\4#\4{\0\11\0)\0n@*\10\7\0"
  .."\26 \12\24\15\7\0∂\24\7å\18!ã ø\29å$æ\18ô\24\13\1\24\4\25\14"
  .."\10\6\12D \4\6\21>*\16ÙÏƒ¸Ï\50\50\17\57\57\49\0\47ƒ‰Ù¸ÙÏ\16Ó"
  .."\16Ó\17\57\17\57\18\57\17\18\57\48@\29\48\31\48 \48!\48\34†\0"
  .."†\1†\2†\10†\11¢\22†\23†\24†\25†\26\14\93\1#\34\6\21\20\22\51"
  .."\50\54\55\53\55\17#\53\14\1#\34&\53\52\54;\1\53\46\1#\34\6\7"
  .."\53>\1\51\50\22\23\30\1\2æ=°£zlòÆ\1ππ;≥Ä´Ã˚Û˜\1Üì^¿\91fªXã≈="
  .."& \2\51qpep”∫)L˝Å¶d_¡¢ª¬\29Üy\54\52∏''RR\50ì\0\0\2\0¡ˇ„\4X\6"
  .."\20\0\11\0\28\0\48@\26\24\12\9\3å\15\9å\21ô\15æ\27õ\25\0\18\18"
  .."G\24\12\6\6\26F\29\16ÙÏ\50\50¸Ï\49\0\47Ï‰ÙÏ\16Ó\17\57\57\48\1"
  .."\52&#\34\6\21\20\22\51\50\54\1\54\54\51\50\18\17\16\2#\34&'\21"
  .."#\17\51\3ñàÖÜääÜÖà˝„,õf ËÈÀdô\46∏∏\2\47÷⁄€’‘‹⁄\2xRX˛…˛Ô˛Î˛≈W"
  .."Sç\6\20\0\0\1\0√ˇ„\4%\4{\0\25\0\47@\26\12ã\13¿\16\0ã\25¿\22å"
  .."\3\16å\9æ\3ô\26\19\18\12\0\6F\26\16Ùƒ\50Ï\49\0\16‰ÙÏ\16˛ÙÓ\16"
  .."ıÓ\48%\6\6# \0\17\16\0!\50\22\23\21&&#\34\6\21\20\22\51\50\54"
  .."\55\4%JùR˛¸˛€\1%\1\4QöNIì\93≠∫ª¨`òA\57++\1\56\1\20\1\20\1\56"
  .."*,¡A:‡–œ·;>\0\0\2\0{ˇ„\4\18\6\20\0\16\0\28\0\48@\26\5\0\20\26"
  .."å\14\20å\8ô\14æ\1õ\3\23\4\0\6\2G\17\18\11H\29\16ÙÏ¸Ï\50\50\49"
  .."\0\47Ï‰ÙÏ\16Ó\17\57\57\48\1\17\51\17#\53\6\6#\34\2\17\16\18\51"
  .."\50\22\1\20\22\51\50\54\53\52&#\34\6\3Z∏∏\46ôdÀÈÍ eö˛\15àÖÖã"
  .."ãÖÖà\3—\2C˘ÏçSW\1;\1\21\1\17\1\55W˛\11÷⁄‹‘’€⁄\0\0\2\0{ˇ„\4X\4"
  .."{\0\21\0\28\0E@&\0\22\3\1\10ã\9ç\6\22∂\1\6å\13\1¡\25å\19æ\13"
  System.VERA=System.VERA
  .."ô\29\3\2\28\16\9\22\6\0I\28\18\16H\29\16ÙÏ¸Ïƒ\17\18\57\57\49"
  .."\0\16‰ÙÏ‰\16Ó\16Ó\16ÙÓ\18\57\17\57\48\1\21!\21\20\22\51\50\54"
  .."\55\21\6\6# \0\17\16\0\51\50\18\7&&#\34\6\7\4X¸„øÆX¿mi√\91˛˚"
  .."˛⁄\1 ÷˜∏\4ëàÖ¨\16\2^Z\6∑»\56\57∑++\1\57\1\19\1\12\1@˛ﬁ≈¢©∞ú"
  .."\0\1\0√\0\0\4'\6\20\0\19\0\52@\26\5\16\1\12\8∂\6\1å\0õ\14\6¬"
  .."\10\2\19\7\0\9\5\6\13\15\11\20\16‘<ƒ¸<ƒ\50\57\57\49\0\47‰\50"
  .."¸Ï\16Ó\50\18\57\57\48\1\21#\34\6\21\21!\21!\17#\17!\53!\53\52"
  .."\54\51\4'—cM\1Å˛\127∏˛’\1+©≥\6\20ôQgcè¸\47\3—èN∏Æ\0\0\2\0{˛H"
  .."\4\18\4{\0\11\0)\0H@'\25\12\30\27'\9\3\18ã\19\22\9å\30\22å\15"
  .."\3å$æ\30\15√(¬*'\25\0\6\12G\6\18\18!H*\16ÙƒÏ¸Ï\50\50\49\0\16"
  .."‰‰ƒÙÏ\16Ó\16Ó\16’Ó\17\18\57\57\17\57\57\48\1\52&#\34\6\21\20"
  .."\22\51\50\54\19\20\2#\34&'\53\22\22\51\50\54=\2\6\6#\34\2\17"
  .."\16\18\51\50\22\23\53\51\3ZáÅáéèà\127á∏ÓÁL¶Sb†Cïà,òmƒÍÍƒlñ\47"
  .."∏\2\57œ◊◊œœŸ⁄˛›¸˛¸\28\27∂\46,¢∞\8}^\92\1:\1\7\1\8\1:VZë\0\0\1"
  .."\0√\0\0\4\27\6\20\0\19\0,@\24\9\14\3\0\3\1\6å\17æ\12õ\10\1\2"
  .."\6\0J\13\9\6\11F\20\16ÙÏ\50¸Ï\49\0\47<ÏÙÏ\17\23\57\57\48\1\17"
  .."#\17\52&#\34\6\21\17#\17\51\17\54\54\51\50\22\4\27πjqÅã∏∏\49"
  .."®s´©\2∂˝J\2∂óé∑´˝á\6\20˝§`c·\0\0\2\0≤\0\0\4D\6\20\0\9\0\13\0"
  .."\46@\25\8∂\0\12ƒ\10õ\0¬\6\2∂\4\3L\11\1\6\5L\0K\10\7\14\16‘<‰"
  .."Ï¸<Ï\49\0\47Ï\50‰¸Ï\16Ó\48\1!\17!\21!\53!\17!\1\51\21#\1\0\1"
  .."◊\1m¸n\1m˛·\1\31∏∏\4`¸\47èè\3B\2CÈ\0\0\2\0∫˛V\3\16\6\20\0\13"
  .."\0\17\0\56@\29\5\0\1\10å\8\1∂\3\16ƒ\14õ\3¬\8√\18\11\8\2\9\2\15"
  .."\4\6\14\0\18\16‘<Ï\50ƒƒ\18\57\57\49\0\16‰‰¸Ï\16Ó\16Ó\17\57\57"
  .."\48\5\17!\53!\17\20\6##\53\51\50\54\17\51\21#\2X˛√\1ı≥•˛ÍZZ∏"
  .."∏\20\3Âè˚å√”ú}\6•È\0\0\1\0Ï\0\0\4≤\6\20\0\11\0≈@:\8\23\9\8\5"
  .."\6\5\7\23\6\6\5\9\23\3\2\8\23\7\8\3\2\5\23\6\5\2\3\2\4\23\3\3"
  .."\2B\8\5\2\3\3¬\0õ\10\6\8\5\4\3\6\9\1\6\6D\0E\12\16ÙÏÏ\50\17\23"
  .."\57\49\0\47<Ï‰\23\57\48KSX\7\16\5Ì\7\16\8Ì\7\8Ì\7\4Ì\7\16\5Ì"
  .."\7\16\8ÌY\34≤\8\7\1\1\93@R\6\2\8\8\22\2\24\5\24\8\53\2\52\5\54"
  .."\8F\2f\2u\2v\5\12\9\3\8\8\25\3\23\4\24\5\25\6\26\7\24\8(\3'\5"
  .."(\7;\3;\4\55\5\57\7\55\8J\3I\7Y\6Y\7k\3i\4i\6i\7y\3x\5y\6y\7"
  .."\28\93\0\93\19\51\17\1\51\9\1#\1\7\17#Ïæ\1„‡˛G\1˛·˛bâæ\6\20¸"
  System.VERA=System.VERA
  .."{\1—˛Z˝F\2BÅ˛?\0\1\0†\0\0\4\10\6\31\0\13\0&@\19\9\0\3\10∂\12"
  .."≈\3∂\5\3\6\4\0\6\11L\9\14\16‘Ï¸Ã\57\57\49\0\47Ï¸Ï\17\57\57\48"
  .."\1\20\22\51\51\21#\34&\53\17!\53!\2\127\91Y◊È•µ˛Ÿ\1ﬂ\1ñ|~ú‘¬"
  .."\3˘ê\0\1\0m\0\0\4o\4{\0\34\0Ã@'\24\18\15\9\4\7\0\29\27\6\7\21"
  .."\12å \3æ\27¬\25\16\7\0\17\15\8M\6N\17M\15N\28\24M\26E#\16Ù¸<"
  .."¸Ï¸Ï\17\18\57\49\0\47<<‰Ù<Ï\50\17\57\17\57\57\17\23\57\48@G\48"
  .."\4\48\5\48\6\48\7\48\8\48\9\48\10\48\11?\22?\23?\24?\25?\26?"
  .."\27?\28?\29?\30Ä\3Ä\4Ä\5Ä\6Ä\7Ä\8Ä\9Ä\10Ä\11è\22è\23è\24è\25"
  .."è\26è\27è\28è\29è\30#\1\93\1K∞\12TK∞\17T\91K∞\22T\91XΩ\0#\0@"
  .."\0\1\0#\0#ˇ¿\56\17\55\56Y\1K∞\16TXΩ\0#ˇ¿\0\1\0#\0#\0@\56\17\55"
  .."\56Y\1>\1\51\50\22\25\1#\17\52&#\34\6\21\17#\17\52&#\34\6\21"
  .."\17#\17\51\21>\1\51\50\22\2§\34iJáo®\53FP;®\57JI\57ßß!c?Le\3"
  .."ÓHE—˛ﬂ˝w\2ÅÌs{Â˝\127\2Åp{Â˝\127\4``<?F\0\1\0√\0\0\4\27\4{\0"
  .."\19\0,@\24\9\14\3\0\3\1\6å\17æ\12¬\10\1\2\6\0J\13\9\6\11F\20"
  .."\16ÙÏ\50¸Ï\49\0\47<‰ÙÏ\17\23\57\57\48\1\17#\17\52&#\34\6\21\17"
  .."#\17\51\21\54\54\51\50\22\4\27πjqÅã∏∏\49®s´©\2∂˝J\2∂óé∑´˝á\4"
  .."`®`c·\0\2\0âˇ„\4H\4{\0\11\0\23\0#@\19\6å\18\0å\12æ\18ô\24\9\18"
  .."\15D\3\18\21>\24\16ÙÏ¸Ï\49\0\16‰ÙÏ\16Ó\48\1\34\6\21\20\22\51"
  .."\50\54\53\52&'\50\18\17\16\2#\34\2\17\16\18\2håêêåçêêçÈ˜ˆÍÈˆ"
  .."ˆ\3ﬂ⁄÷’€€’÷⁄ú˛“˛‚˛·˛”\1\45\1\31\1\30\1\46\0\0\2\0æ˛V\4T\4{\0"
  .."\16\0\28\0\51@\28\5\0\20\26å\14\20å\8æ\14ô\1√\3¬\29\17\18\11"
  .."G\23\4\0\6\2F\29\16ÙÏ\50\50¸Ï\49\0\16‰‰‰ÙÏ\16Ó\17\57\57\48%\17"
  .."#\17\51\21\54\54\51\50\18\17\16\2#\34&\1\52&#\34\6\21\20\22\51"
  .."\50\54\1wππ\46ôdÀÁË fô\1áÖÜääÜÖáç˝…\6\10èSW˛∆˛Í˛Ô˛…W\1ı÷⁄€’"
  .."‘‹⁄\0\0\2\0â˛R\4\31\4w\0\11\0\28\0\51@\28\24\12\9\3å\15\9å\21"
  .."æ\15ô\27√\25¬\29\24\12\6\6\26G\0\18\18>\29\16ÙÏ¸Ï\50\50\49\0"
  .."\16‰‰‰ÙÏ\16Ó\17\57\57\48\1\20\22\51\50\54\53\52&#\34\6\1\6\6"
  .."#\34\2\17\16\18\51\50\22\23\53\51\17#\1LáÖÖââÖÖá\2\26\45ôe…È"
  .."Ë dô\46ππ\2+÷⁄€’’€⁄˝äSY\1\55\1\17\1\22\1:WSè˘ˆ\0\1\1j\0\0\4É"
  .."\4{\0\17\0O@\19\6\7\11\3\0\17\3ó\14æ\9¬\7\10\6\6\0\8\18\16‘ƒ"
  .."Ï\50\49\0\47‰ÙÏ‘Ã\17\57\17\57\48@%\16\0\16\1\16\17 \0 \1 \17"
  .."\48\0\48\1\51\16\48\17@\0@\1C\16@\17P\0P\1P\16P\17\18\93\1\46"
  System.VERA=System.VERA
  .."\1#\34\6\21\17#\17\51\21>\1\51\50\22\23\4É;zI¨∂ππ\46øÉDv\54\3"
  .."y\46*ÿÃ˝”\4`€w\127\34$\0\0\1\0’ˇ„\4\6\4{\0'\0u@@\13\12\2\14\11"
  .."\23\31\30\8\9\2\7\10\23\30\31\30B\29\30\24\10\11\30\31\4\21\0"
  .."ã\1¿\4\20ã\21¿\24å\17\4å%æ\17ô(\29\10\11\31\27\7\0O\27\6\14I"
  .."\7\6\20\34E(\16ÙƒÏ¸Ï‰\17\18\57\57\57\57\49\0\16‰ÙÏ\16˛ıÓ\16ı"
  .."Ó\18\23\57\17\18\57\48KSX\7\16\14Ì\17\23\57\7\14Ì\17\23\57Y\34"
  .."\1\21&&#\34\6\21\20\22\23\23\22\22\21\20\6#\34&'\53\22\22\51"
  .."\50\54\53\52\47\2&&\53\52\54\51\50\22\3ÕO†S}{\92∑JâçÏ“S∂jgºT"
  .."zÜı\8Eüí⁄ Z¶\4\57¥\46\46QSKJ#\14\26ú}¶ª##æ\53\53cYÄ\49\2\14\31"
  .."ì\127°Ø!\0\1\0É\0\0\4\8\5û\0\19\0\49@\24\14\5\8\15\3∂\0\17\1"
  .."¬\8∂\10\8\11\9\2\4\0\6\16\18\14\20\16‘<ƒ¸<ƒ\50\57\57\49\0\47"
  .."ÏÙ<ƒÏ\50\17\57\57\48\1\17!\21!\17\20\22\51\51\21#\34&\53\17!"
  .."\53!\17\2f\1¢˛^^uœ·œ™˛’\1+\5û˛¬è˝†|bì¶À\2`è\1>\0\1\0√ˇ„\4\27"
  .."\4^\0\19\0,@\24\9\14\3\0\3\1\6å\17ô\10\1¬\12\13\9\6\11J\2\6\0"
  .."F\20\16ÙÏ¸Ï\50\49\0\47‰\50ÙÏ\17\23\57\57\48\19\17\51\17\20\22"
  .."\51\50\54\53\17\51\17#\53\6\6#\34&√∏kpÇäππ\49©q¨®\1®\2∂˝Jóé∑"
  .."´\2y˚¢®ad·\0\0\1\0d\0\0\4m\4`\0\6\0e@)\3\23\4\5\4\2\23\1\2\5"
  .."\5\4\2\23\3\2\6\0\6\1\23\0\0\6B\2\3\0¬\5\6\5\3\2\1\5\4I\0E\7"
  .."\16ÙÏ\23\57\49\0\47‰\50\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16"
  .."\5ÌY\34≤'\2\1\0\93@\14\7\0\7\1\8\3\8\4\4\5\2%\2\2\93\1\93\19"
  .."\51\9\1\51\1#dø\1E\1Fø˛rÌ\4`¸T\3¨˚†\0\1\0\0\0\0\4—\4`\0\12\1"
  .."\17@E\11\2\3\2\10\9\10\3\3\2\10\11\10\4\5\4\9\5\5\4\6\23\7\8"
  .."\7\5\23\4\5\8\8\7\2\23\3\2\12\0\12\1\23\0\12B\10\5\2\3\8\3\6"
  .."\0¬\11\8\12\11\10\9\8\6\5\4\3\2\1\11\7\0\47Ã\23\57\49\0\47<Ù"
  .."<ƒ\17\23\57\48KSX\7\5Ì\7\16\8Ì\7\16\8Ì\7\16\5Ì\7\16\5…\7\16\8"
  .."…\7\16\8…\7\16\5…Y\34≤\15\10\1\0\93@å\11\9\4\11\31\0\31\1\29"
  .."\2\26\3\28\4\25\5\28\9\27\10\26\11\31\12&\0&\1)\2&\5)\6)\7#\8"
  ..",\12\57\2\54\5\57\6\57\7\51\8<\12E\8I\9F\11J\12V\8X\9W\11Y\12"
  .."f\2i\3f\4i\5j\9e\11v\2z\5x\8|\9r\11\45\15\10\25\2\31\3\31\4\25"
  .."\5\31\10\31\10+\2+\5>\2>\5<\10H\10Y\10j\2i\5h\10{\2\127\3y\4"
  .."\127\4z\5|\10\127\10\24\93\1\93\17\51\27\1\51\27\1\51\1#\11\1"
  .."#∂√†ù¢√∂˛˙∞≥≤∞\4`¸w\2B˝æ\3â˚†\2f˝ö\0\0\1\0L\0\0\4Ö\4`\0\11\0"
  System.VERA=System.VERA
  .."©@H\5\23\6\7\6\4\23\3\4\7\7\6\4\23\5\4\1\2\1\3\23\2\2\1\11\23"
  .."\0\1\0\10\23\9\10\1\1\0\10\23\11\10\7\8\7\9\23\8\8\7B\10\7\4"
  .."\1\4\8\0¬\5\2\10\7\4\1\4\8\0\2I\8\6E\12\16Ùƒ¸ƒ\17\23\57\49\0"
  .."\47<‰\50\23\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5Ì\7\16\5Ì"
  .."\7\16\8Ì\7\16\8Ì\7\16\5ÌY\34≤\7\10\1\0\93@\30\9\1\6\7f\1i\7v"
  .."\1y\7\6\7\1\7\7\6\10\21\10:\4\52\10Z\4V\10\8\93\1\93\9\2#\9\1"
  .."#\9\1\51\9\1\4^˛o\1∏’˛∏˛π’\1∏˛oÃ\1)\1'\4`˝Ë˝∏\1¡˛?\2H\2\24˛k"
  .."\1ï\0\0\1\0h˛V\4Å\4`\0\18\0†@E\13\23\14\13\2\3\2\10\11\2\9\12"
  .."\23\3\3\2\17\23\18\0\18\16\23\15\16\0\0\18\16\23\17\16\13\14"
  .."\13\15\23\14\14\13B\16\19\13\0\14\9å\7√\17\14¬\19\17\16\15\13"
  .."\10\7\0\7\18\8\18I\14E\19\16ÙÏƒ\17\23\57\49\0\16‰\50ÙÏ\17\57"
  .."\57\18\57\48KSX\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5Ì\7\16\5Ì\17\23"
  .."\57\7\16\8ÌY\34≤\56\18\1\1\93@\26\4\16v\16\2\8\17\8\18\25\12"
  .."\25\13&\14&\15\56\17I\17I\18Y\13\10\93\0\93\1\6\7\2\7\14\1+\1"
  .."\53\51\50\54\55\1\51\9\1\51\3Z\46Gc\34\46ä\92îmQ\92G˛O√\1L\1"
  .."G√\1huø˛¯:NNö^ƒ\4N¸î\3l\0\0\1\0À\0\0\4\16\4b\0\9\0X@\28\3\23"
  .."\7\8\7\8\23\2\3\2B\8∂\0¬\3∂\5\8\3\0\4\1I\0\6E\10\16ÙƒÏ\50\17"
  .."\57\57\49\0\47ÏÙÏ\48KSX\7\16\5Ì\7\16\5ÌY\34≤\56\8\1\1\93@\21"
  .."\54\3\56\8E\3J\8W\3X\8e\3j\8u\3z\8\10\93\19!\21\1!\21!\53\1!"
  .."„\3\45˝}\2É¸ª\2É˝ï\4b®¸‹ñ™\3%\0\1\0›˛≤\3Ù\6\20\0$\0f@\53\25\15"
  .."\21\11\6%\9\26\16\21\29\11\5 !\3\0\11∂\9\0∂\1∆\9«\21∂\19µ%\12"
  .."\9\10\5$\22\25\0\29\10\5\19\2\20\0 \25=\10\15\5%\16‘<ƒ¸<ƒ\50"
  .."\57\57\17\18\57\17\18\57\57\17\18\57\57\49\0\16¸Ï‰ÙÏ\16Ó\18\23"
  .."\57\18\57\17\57\57\17\18\57\17\18\57\57\48\5\21#\34&\53\53\52"
  .."&##\53\51\50\54\53\53\52\54\51\51\21#\34\6\21\21\20\6\7\22\22"
  .."\21\21\20\22\51\3Ù@˘©kå>>çj©˘@FåU\91noZUåæêî›Ôótèrñ›ìèWé¯ùé"
  .."\25\27éú¯èV\0\1\2\18˛\29\2æ\6\29\0\3\0\18∑\1\0µ\4\0\4\2\4\16"
  .."‘Ï\49\0\16¸Ã\48\1\17#\17\2æ¨\6\29¯\0\8\0\0\0\1\0›˛≤\3Ù\6\20\0"
  .."$\0j@\55\31%\27\22\12\15\8\27\11\21\25\15\4\5 \3\0\25∂\27\0∂"
  .."#∆\27«\15∂\17µ%\28\25\26\21\15\1\4\0\8\26\21#\18\4\0\26\31\21"
  .."=\16\0\11\4%\16‘<ƒ\50¸<ƒ\17\18\57\57\17\18\57\17\18\57\57\17"
  .."\18\57\57\49\0\16¸Ï‰ÙÏ\16Ó\18\23\57\17\18\57\57\17\57\17\57\57"
  System.VERA=System.VERA
  .."\17\18\57\48\23\51\50\54\53\53\52\54\55&&\53\53\52&##\53\51\50"
  .."\22\21\21\20\22\51\51\21#\34\6\21\21\20\6##›DçVZon\91VçD>˘®k"
  .."ç@@çk®˘>æXç¯úé\27\25éù¯çXèì›ñrètóÔ›î\0\0\1\0X\1Ï\4y\3\12\0\27"
  .."\0&@\18\1\11\4\15\0\14\4†\25\18\0†\11\28\0\14'\28\16¸ƒ\49\0\16"
  .."‘¸<‘Ï\50\18\57\17\18\57\48\1\21\6\6#\34'&'&&#\34\6\7\53\54\54"
  .."\51\50\22\23\22\23\22\51\50\54\4yKèOZq\22\11Mg\51OçINíS\53dJ"
  .."\12\21t\93Fâ\3\12Æ;\55\51\10\4!\24;?Æ<\54\22\31\5\10\55=ˇˇ\0"
  .."%\0\0\4¨\7N\0'\0$\0\0\0\0\0\7\1\3\0\0\1u\0\3\0%\0\0\4¨\7m\0\11"
  .."\0\14\0!\0¡@W\12%\13\12\27\28\27\14%\28\27\30%\28\27\29%\28\28"
  .."\27 %\15!\31%\15!\13%!\15!\12%\14\12\15\15!B\12\27\15\9\30ó\13"
  .."\3»\21\9ê\13… \28\29\28\24 !\31\13\18\6\30\14\24\12\6\27\0P\24"
  .."\15\6P\18\24K\28\47\18K!\34\16‹‰¸‰\16Ó\50\16Ó\50\17\57\17\57"
  .."\57\17\18\57\57\17\57\17\18\57\49\0\47<ÊÊ÷Ó\16Ó\18\57\57\57\48"
  .."KSX\7\16\8Ì\7\16\5Ì\7\5Ì\7\5Ì\7\16\5Ì\7\5Ì\7\5Ì\7\16\8ÌY\34≤"
  .."Ä\31\1\0\93@\20Ö\13ä\14ä\30Ö\31\4è\12è\12Ä\13Ä\14Ä\30\5\93\1"
  .."\93\1\52&#\34\6\21\20\22\51\50\54\7\3!\1\46\1\53\52\54\51\50"
  .."\22\21\20\6\7\1#\3!\3#\3\0Y?@WX??Yò’\1™˛î:A†rr°@;\1¨—n˝ıl—\6"
  .."Z?YWA?XX¸˝\8\3P!yIr°°rIv$˙â\1Ö˛{\0ˇˇ\0ã˛u\4\49\5\0'\0&\0\0\0"
  .."\0\0\7\0›\0d\0\0ˇˇ\0≈\0\0\4N\7k\0'\0(\0\0\0\0\0\7\1\4\0\18\1"
  .."uˇˇ\0ã\0\0\4F\7^\0'\0\49\0\0\0\0\0\7\1\5ˇÓ\1uˇˇ\0uˇ„\4\92\7N"
  .."\0'\0\50\0\0\0\0\0\7\1\3\0\0\1uˇˇ\0ìˇ„\4=\7N\0'\0\56\0\0\0\0"
  .."\0\7\1\3\0\0\1uˇˇ\0Öˇ„\4#\6f\0'\0D\0\0\0\0\0\7\0ç\0\0\0\0ˇˇ\0"
  .."Öˇ„\4#\6f\0'\0D\0\0\0\0\0\7\0C\0\0\0\0ˇˇ\0Öˇ„\4#\6f\0'\0D\0\0"
  .."\0\0\0\7\0◊\0\0\0\0ˇˇ\0Öˇ„\4#\6\16\0'\0D\0\0\0\0\0\7\0é\0\0\0"
  .."\0ˇˇ\0Öˇ„\4#\6\55\0'\0D\0\0\0\0\0\7\0ÿ\0\0\0\0ˇˇ\0Öˇ„\4#\7\6"
  .."\0'\0D\0\0\0\0\0\7\0‹\0\0\0\0ˇˇ\0√˛u\4%\4{\0'\0F\0\0\0\0\0\7"
  .."\0›\0h\0\0ˇˇ\0{ˇ„\4X\6f\0'\0H\0\0\0\0\0\7\0ç\0\14\0\0ˇˇ\0{ˇ„"
  .."\4X\6f\0'\0H\0\0\0\0\0\7\0C\0\14\0\0ˇˇ\0{ˇ„\4X\6f\0'\0H\0\0\0"
  .."\0\0\7\0◊\0\14\0\0ˇˇ\0{ˇ„\4X\6\16\0'\0H\0\0\0\0\0\7\0é\0\14\0"
  .."\0ˇˇ\0≤\0\0\4D\6f\0'\0÷\0\0\0\0\0\7\0ç\0\0\0\0ˇˇ\0≤\0\0\4D\6"
  .."f\0'\0÷\0\0\0\0\0\7\0C\0\0\0\0ˇˇ\0≤\0\0\4D\6f\0'\0÷\0\0\0\0\0"
  .."\7\0◊\0\0\0\0ˇˇ\0≤\0\0\4D\6\16\0'\0÷\0\0\0\0\0\7\0é\0\0\0\0ˇ"
  System.VERA=System.VERA
  .."ˇ\0√\0\0\4\27\6\55\0'\0Q\0\0\0\0\0\7\0ÿ\0\0\0\0ˇˇ\0âˇ„\4H\6f"
  .."\0'\0R\0\0\0\0\0\7\0ç\0\0\0\0ˇˇ\0âˇ„\4H\6f\0'\0R\0\0\0\0\0\7"
  .."\0C\0\0\0\0ˇˇ\0âˇ„\4H\6f\0'\0R\0\0\0\0\0\7\0◊\0\0\0\0ˇˇ\0âˇ„"
  .."\4H\6\16\0'\0R\0\0\0\0\0\7\0é\0\0\0\0ˇˇ\0âˇ„\4H\6\55\0'\0R\0"
  .."\0\0\0\0\7\0ÿ\0\0\0\0ˇˇ\0√ˇ„\4\27\6f\0'\0X\0\0\0\0\0\7\0ç\0\0"
  .."\0\0ˇˇ\0√ˇ„\4\27\6f\0'\0X\0\0\0\0\0\7\0C\0\0\0\0ˇˇ\0√ˇ„\4\27"
  .."\6f\0'\0X\0\0\0\0\0\7\0◊\0\0\0\0ˇˇ\0√ˇ„\4\27\6\16\0'\0X\0\0\0"
  .."\0\0\7\0é\0\0\0\0\0\1\0¢ˇ;\4\47\5’\0\11\0'@\20\8\4À\10\2\0à\6"
  .." \12\3R\5\1Q\9R\7\0\12\16‘<Ï¸<Ï\49\0\16‰Ù‘<Ï\50\48\1\51\17!\21"
  .."!\17#\17!\53!\2\16±\1n˛í±˛í\1n\5’˛\92ô˚£\4\93ô\0\0\2\1+\3u\3"
  .."¶\5\0\14\0\26\0 @\17\21Ã\9Õ\15Ã\0ñ\27\24S\6T\18S\12\27\16‘Ï"
  .."¸Ï\49\0\16ÙÏ¸Ï\48\1\50\22\23\22\22\21\20\6#\34&\53\52\54\23\34"
  .."\6\21\20\22\51\50\54\53\52&\2hAu,\45\47∫Üá¥∏ÖOomOPqp\5\49\46"
  .."\45rBÑ∑¥áÜ∫ÅoPPlnNOp\0\0\2\0’˛«\4%\5ò\0\26\0!\0N@*\27\8\5\4\28"
  .."\0ã\1ç\28\9ã\8ç\5À\12\28À\22\24\21æ\15\12ô\13\34\27\21\14\7\23"
  .."\12\4\8\0\31\30\18E\34\16ÙÏ‘<‘<<Ï\50\50\49\0\16ƒ‰\50Ù<ƒÏ\16˛"
  .."ÙÓ\16ıÓ\17\57\17\18\57\48\1\21&&'\17\54\54\55\21\6\6\7\17#\17"
  .."&\0\53\52\0\55\17\51\17\22\22\1\17\6\6\21\20\22\4%CÇ??ÉBIÇ\57"
  .."g·˛¸\1\7ﬁg\57Ç˛ﬁÑ††\4\53¨(,\4¸ö\5\45(¨\31\34\3˛‚\1\30\22\1\57"
  .."˚˙\1=\19\1\31˛·\3\34¸+\3`\12Ï∏∏Î\0\1\0ã\0\0\4X\5\0\27\0>@ \7"
  .."\22\1\18\10∂\20\8\12\1ã\0ß\4ó\25ñ\16\12ó\14\0\13\9\11\7\30\15"
  .."\19\21\17\28\16‘<ƒƒ¸<ƒ‘ƒ\49\0\47Ï\50ÙÏÙÏ\16‘<Ó\50\18\57\57\48"
  .."\1\21&&#\34\6\21\21!\21!\17!\21!\53\51\17#\53\51\53\52\54\51"
  .."\50\22\4D>\127CÜ\127\1s˛ç\2\25¸\51Ï««€ﬂAâ\5∂∏,,≥¿Ÿè˛\47™™\1—"
  .."èÓ˛˙\29\0\2\0«ˇ=\4\12\5\0\50\0>\0j@<#$\30\57\51\11\17$*\4\1"
  .."\27è\26Œ\30œ\23\1è\0Œ\4œ\48ñ\23?#\7\17<!*\54\11$\57\51\4\7!U"
  .."\20\7U\45\20<U\0&\14\45\26&\54U'?\16‘Ï‰ƒ‘‰Ïƒ\16Ó\16Ó\17\23\57"
  .."\18\57\17\18\57\18\57\49\0\16ƒÙÏÙÏ\16ÓˆÓ\17\23\57\57\57\17\18"
  .."\57\48\1\21&&#\34\6\21\20\23\22\23\22\22\21\20\6\7\22\22\21\20"
  .."\6#\34&'\53\22\22\51\50\54\53\52''&&\53\52\54\55&&\53\52\54\51"
  .."\50\22\1\6\6\21\20\22\23\54\54\53\52&\3®Sè\57akÕ\26\14‘Ç\91\93"
  .."=:Ã≠IõWWî\57fq›\24÷Ä\93\91<;»ßHô˛ç>=ç˜><è\5∂§''PGZs\15\8wöeZ"
  System.VERA=System.VERA
  .."å\53\52m@é®\29\29§''TLf{\14xôf\91è\49,pEÇü\29˝’\45Z\47LáÖ\45"
  .."Z\47Là\0\0\1\1?\1—\3ë\4!\0\11\0\18∑\9–\3\12\6V\0\12\16‘Ï\49\0"
  .."\16‘‰\48\1\52\54\51\50\22\21\20\6#\34&\1?¨}|≠Æ}|´\2˙|´¨{|≠´\0"
  .."\0\1\0jˇ;\4\6\5’\0\13\0#@\17\4\8\0à\6\2\14\0\7W\5\3W\1\49\11"
  .."\14\16‹¸¸‘Ï\57\49\0\16ƒ\50ÙƒÃ\48\1!\17#\17#\17#\17&&\53\52$\2"
  .."F\1¿çøç◊Ï\1\5\5’˘f\6\31˘·\3N\17›∏æË\0\0\1\0ºˇ„\4}\6\20\0\47\0"
  .."V@\49\45'!\12\4\6\13 \0\4*\22ã\23\26å\19*å\3õ\19ô\46\12\9\13"
  .."\29 !'\9\1$'\6\6\29\6$\16\22\45\6\16D\0F\48\16ÙÏ¸Ã\16∆Ó‘Ó\16"
  .."Ó\17\57\57\18\57\18\57\49\0\47‰˛Ó\16˛’Ó\18\23\57\23\57\48\19"
  .."\52\54\51\50\22\23\6\6\21\20\22\23\23\22\22\21\20\6#\34&'\53"
  .."\22\22\51\50\54\53\52&''&&\53\52\54\55&&#\34\6\21\17#º“ÿÃ“\2"
  .."õ®\55C:óo‡ƒEáBLÖ;lÄAxC\92\91¢ú\2yqyrª\4q’Œ›ÿ\14|d\49M*%\93§t"
  .."ö≤\25\24§\31\30aQG_J'\56ÖOÄ´#krÉã˚ì\0\0\4\0\0\0}\4—\5N\0\19\0"
  .."\28\0\52\0L\0Ö@I\15\14\13\3\16\12\93\9\10\9\11\93\10\10\9B\12"
  .."\10\6\22\9\10\22◊\15\20◊\0\17\10÷A‘)\0’\53‘)”\29—M\23\20\15\12"
  .."\4\0\6\16\9\26\3\21\16\92\18\26\92\10\3\91G\7#\18X;\7#Y\47\47"
  .."Ê˛Â\16˛ıƒÓ\16Ó\50\17\18\57\17\57\57\23\57\49\0\16ÙÏ¸‰\16˛Ì\50"
  .."\16Ó÷Ó\18\57\18\57\18\57\48KSX\7\16\5Ì\7\16\4Ì\17\23\57Y\34\1"
  .."\50\22\21\20\6\7\22\22\23\23#'&&##\17#\17\23#\21\51\50\54\53"
  .."\52&\3\50\22\23\22\22\21\20\6\7\6\6#\34&'&&\53\52\54\55\54\54"
  .."\23\34\6\7\6\6\21\20\22\23\22\22\51\50\54\55\54\54\53\52&'&&"
  .."\2XìêXP\19:&rèk\49=\45\55ÇËffZJJD\127⁄ZZ\92\91\91\91⁄~}⁄\91\91"
  .."\91\92ZZ⁄~jµKKMMKLµijµLLKLKKµ\4LbeG\93\14\5C;∫ÆP*˛ÿ\2∂TË\54?"
  ..">\53\1VZZ\91‹~}⁄\91\91\91\91\91\91⁄}~‹\91ZZgJKK∏jh∑KLLLLLµij"
  .."∏KKJ\0\3\0\0\0}\4—\5N\0\25\0\49\0I\0D@'\13⁄\14\10⁄\17‹&‘>\1⁄"
  .."\0\4⁄\23Ÿ\26‘>”\50—J\7\92\20\13\0^,\7\56\20 \7\56YD\47Ê˛≈\16"
  .."˛Â\50\16Ó\49\0\16ÙÏ¸ÙÏ‘Ï\16˛˝Ó÷Ó\48\1\21&&#\34\6\21\20\22\51"
  .."\50\54\55\21\6\6#\34&\53\52\54\51\50\22'\34\6\7\6\6\21\20\22"
  .."\23\22\22\51\50\54\55\54\54\53\52&'&&'\50\22\23\22\22\21\20\6"
  .."\7\6\6#\34&'&&\53\52\54\55\54\54\3`:o:uáåÇ\56g\50\52r=¥œ–≥=r"
  .."ƒjµKKMMKLµijµLLKLKKµk\127⁄ZZ\92\91\91\91⁄~}⁄\91\91\91\92ZZ⁄\4"
  .."\47l\28\27ïÄÑé\25\26h\23\22»¨≠ \22°JKK∏jh∑KLLLLLµij∏KKJgZZ\91"
  System.VERA=System.VERA
  .."‹~}⁄\91\91\91\91\91\91⁄}~‹\91ZZ\0\2\0\0\3ì\4f\5’\0\7\0\20\0h"
  .."@\54\15\9\10\9\14\10\10\9\17\8\9\8\16\9\9\8B\17\14\9\3\1\15\18"
  .."\12\3\5\1◊\10\8\0à\21\16\15\10\9\8\5\17\13`\11\17`\19\0_\2`\4"
  .."_\6\47¸˛Ï’Ó÷Ó\17\23\57\49\0\16Ù<<Ï\50‘<<ƒ\17\23\57\48KSX\7\16"
  .."\5…\7\16\4…\7\16\4…\7\16\5…Y\34\1\21#\17#\17#\53!\19\19\51\17"
  .."#\17\3#\3\17#\17\1∂¢r¢\2¥â}¨rú\55¶q\5’^˛\28\1‰^ˇ\0\1\0˝æ\1‚˛"
  .."”\1\45˛\30\2B\0\1\1€\4Ó\3∫\6f\0\3\0\49@\9\2∫\0π\4\1<\3\4\16‘"
  .."Ï\49\0\16ÙÏ\48\0K∞\14TK∞\9T\91XΩ\0\4ˇ¿\0\1\0\4\0\4\0@\56\17\55"
  .."\56Y\1\51\1#\2Ù∆˛ªö\6f˛à\0\0\2\1?\5F\3ë\6\16\0\3\0\7\0\92@\14"
  .."\6\2ﬁ\4\0›\8\5a\4\1a\0\8\16‘¸‘Ï\49\0\16Ù<Ï\50\48\0K∞\10TK∞\13"
  .."T\91K∞\14T\91XΩ\0\8\0@\0\1\0\8\0\8ˇ¿\56\17\55\56Y\1K∞\13TK∞\14"
  .."T\91XΩ\0\8ˇ¿\0\1\0\8\0\8\0@\56\17\55\56Y\1\51\21#%\51\21#\1?"
  .."ÀÀ\1à  \6\16   \0\0\1\0X\0%\4y\4›\0\19\0<@ \13\12\10\3\2\4\0"
  .."†\6\12\14\10†\18\6\16\8\20\18\14\13\12\8\4\3\2\8\9\5\15\0\20"
  .."\16‘<ƒ\50\23\57\49\0\16‘<ƒ\50¸<ƒ\16˛<ƒ\57\17\18\57\48\19!\19"
  .."\23\7\51\21!\7!\21!\3'\55#\53!\55!X\2áˆ}§À˛≤∏\2\6˝y¯}§…\1J∏˝"
  .."˛\3¢\1;f’™Ï¨˛≈h”¨Ï\0\2\0\0\0\0\4ú\5’\0\15\0\19\0g@\55\13%\15"
  .."\14\12%\15\14\17%\14\15\14\16%\15\15\14B\5ó\3\11ó\17\16\1ó\0"
  .."à\7ó\17∞\3±\13\9\17\16\15\13\12\5\14\10\0\4\8\6\2c\18\10\14\47"
  .."‘<Ó\50÷ƒƒ\17\18\23\57\49\0\47<ÓÓÓÙÓ\50\16Ó\16Ó\48KSX\7\16\5Ì"
  .."\7\16\5Ì\7\5Ì\7\5ÌY\34\1\21!\17!\21!\17!\21!\17!\3#\1\23\3!\17"
  .."\4â˛Æ\1\51˛Õ\1e˝·˛†e∏\1öx \1\53\5’™˛F™˝„™\1\127˛Å\5’™¸¸\3\4\0"
  .."\0\3\0\8ˇ∫\4∞\6\23\0\9\0\19\0+\0k@:+)&\11\10\9\0\4\14\29\31 "
  .."\20\14\3*&\30\3ó\26\14ó&ñ\26ô\31\31\30, #\17*\20\23\11\10\9\0"
  .."\4\6\29#\17)\6+\6\50\23\54\17\50#\53,\16¸Ï¸Ï¿\18\57\17\18\57"
  .."\18\23\57\17\57\57\17\18\57\17\57\57\49\0\47‰ÙÏ\16Ó¿\16¿\17\18"
  .."\57\57\18\57\18\23\57\17\57\57\48\1\22\22\51\50\18\17\52&'\1"
  .."\1&&#\34\2\17\20\22\1\22\18\21\16\2#\34&'\7'\55&\2\53\16\18\51"
  .."\50\22\23\55\23\1s\30ÉTöá\10\10˝›\1¯\25sVùÉ\5\2ª)+˜˝y¥=èg≤ %"
  .."˜¸s≠\57ãd\1\47NZ\1\25\1Inà\45˝À\2œQU˛‹˛ÜPe\2ÊQ˛˛£˛z˛ÄQQÀF¸I\1"
  .."\6û\1á\1ÄRP…J\0\0\3\0)\0˙\4®\3\0\11\0\23\0\47\0\55@\28$\24\9"
  .."\21\3·'!‚\15\9·\45\27ﬂ\48\12\0$\24\18\6d\30\18d*\48\16‘Ï‘Ï\17"
  System.VERA=System.VERA
  .."\57\57\57\57\49\0\16¸<Ï\50¸<Ï\50\17\57\57\48\1\22\22\51\50\54"
  .."\53\52&#\34\6\7&&#\34\6\21\20\22\51\50\54\55\54\54\51\50\22\21"
  .."\20\6#\34&'\6\6#\34&\53\52\54\51\50\22\2∂\57\91=G\91TFBiÀ\56"
  .."\92=G\91SDCj~\47ì\91w¨£~SÄNAÑU}¶ùÑ^à\2sàdÜlkÄutÜcÖjmÅvˇu\127"
  .."€†ß‘dÉ|k÷•≠Œs\0\0\2\0X\0\0\4y\4ì\0\3\0\15\0\46@\24\9„\11\7†\4"
  .."„\13\5\0†\2\6\1\26\8\4\28\12\0\26\14\10\16\16‘<Ï\50¸<Ï\50\49"
  .."\0\47Ï‘<Ï¸<Ï\48\55!\21!\1\17!\21!\17#\17!\53!\17X\4!˚ﬂ\2d\1Ω"
  .."˛C®˛D\1º™™\4ì˛∑™˛¥\1L™\1I\0\2\0V\0\0\4w\4?\0\6\0\10\0(@\22\6"
  .."\5\3\2\0\5\1Â\4‰\7†\8\6\7\4\0(\9\2'\11\16¸<Ï\50\50\57\49\0\47"
  .."ÏÙÏ\23\57\48\1\21\1\53\1\21\5\1\21!\53\4w˚ﬂ\4!¸ﬂ\3!˚ﬂ\1∂∂\1L"
  .."®\1K∏Á˛\10™™\0\0\2\0X\0\0\4y\4?\0\6\0\10\0(@\22\5\4\2\1\0\5\6"
  .."Â\3‰\7†\9\1\8\4(\7\2\0'\11\16¸<<Ï\50\57\49\0\47ÏÙÏ\23\57\48\19"
  .."%%\53\1\21\1\21!\21!X\3#¸›\4!˚ﬂ\4!˚ﬂ\1∂ÍÁ∏˛µ®˛¥V™\0\1\0%\0\0"
  .."\4¨\5’\0\24\0\127@D\3%\4\9\4\2%\1\2\9\9\4\2%\3\2\20\0\20\1%\0"
  .."\0\20B\2\7\5\16\12Á\18\10\23\5Á\21\7\3\0à\14\24\1\17\2\15\8\5"
  .."\3\3\6\4<\11\6e\13\9\30\22\17e\0<\19\15\25\16‘<ÏÏ\50¸<Ï\50Ï\18"
  .."\23\57\18\57\17\57\57\49\0\47‰\50‘<Ï\50‘<Ï\50\17\18\57\48KSX"
  .."\7\16\5Ì\7\16\8Ì\7\16\8Ì\7\16\5ÌY\34\19\51\1\1\51\1\51\21!\7"
  .."\21!\21!\17#\17!\53!\53'!\53\51%◊\1l\1kŸ˛∂¸˛≈V\1ë˛oÀ˛q\1èZ˛À"
  .."Û\5’˝m\2ì˝œoó#o˝Ù\2\12o#óo\0\1\0√˛T\4û\4`\0 \0L@*\19\25\31\3"
  .."\22\6\3\9\12\3\1\18\6å\15ã\28\22ô\0√\10\1¬!\25\11\9 \31\2\0\18"
  .."\9\6\11J\2\6\0F!\16ÙÏ¸Ïƒ\17\18\57\57\17\18\57\49\0\16‰\50‰Ù<"
  .."Ï¸ƒ\17\23\57\17\18\23\57\48\19\17\51\17\20\22\51\50\54\53\17"
  .."\51\17\20\22\51\50\54\55\21\6\6#\34&'\6\6#\34&'\17√∏xo\127Åπ"
  .." !\9\29\28&D\34>K\12\46ÖY\92\127,˛T\6\12˝Héó™¶\2ç¸†;\56\10\13"
  .."î\23\22OOPNLP˝’\0\2\0æˇÁ\4\23\5\45\0\29\0)\0:@\14\0'!\9\27\6"
  .."'\21\6\15!\27\15\21∏\1\13@\10*\12$\3\0\30\18$\24*\16‘Ã‹Ã\57\57"
  .."\17\57\49\0\16‰Ã‹Ã\16Œ\16Œ\17\18\57\17\18\57\48\1\54\54\53\52"
  .."&#\34\6#\34&\53\52\54\51\50\18\17\16\0#\34&\53\52\18\51\50\22"
  .."\7\52&#\34\2\21\20\22\51\50\18\3J\15\15IH\55ê$$\48êe¥÷˛ﬂ’òÀ›"
  .."¢eÇ\11WOmçVPmç\2mW£KÅÉt,\31>b˛ ˛˘˛±˛Fÿ£∆\1\1\91‡t}˛˛œt{\1\4\0"
  .."\0\1\0è˛L\4=\5Ó\0\11\0\55¥\11\5\12\9\0ø\1\15\0\2\0\9\1\15\0\7"
  System.VERA=System.VERA
  .."\1\14\0\2\1\16@\11\12\11\10\8\5\0\5\1\6\3\12\16‘<ƒ\23\57\49\0"
  .."\16‰ÙÏ\16Ó\17\18\57\57\48\1!\21!\53\1\1\53!\21!\1\1L\2Ò¸R\2%"
  .."˝€\3ö˝#\2\10˛’â\92\3ó\3P_å¸›\0\0\1\0ò˛L\4\57\5Ó\0\7\0\31π\0\5"
  .."\1\15@\11\1\3\0\8\4Ä\2\6Ä\0\8\16‘Ï‘Ï\49\0\16ƒ\50‘Ï\48\19\17!"
  .."\17#\17!\17ò\3°õ˝ï˛L\7¢¯^\7\30¯‚\0\0\1\0PˇŸ\4û\4L\0\23\0?@!\11"
  .."\20\14\10\4\17\2\7Í\14\22\18\2Í\0Ë\14Ï\20\0\24\21\10\1h\17g\3"
  .."\19g\21f\24\16ÙÏ‘Ï‰ƒ\17\18\57\49\0\47‰ÙÏ\50\50\16Ó\17\57\57\57"
  .."\17\18\57\48\19!\21#\17\20\22\51\50\54\55\21\6\6#\34&\53\17!"
  .."\17#\17#P\4\49ç\49\55\15,\7#J%q\92˛T¥è\4Lî˝@H?\5\1Ö\13\12É∞\2"
  .."¨¸H\3∏\0\0\1\0Å˛ç\4L\6\14\0%\0\49π\0 \1\18≤\0\26\13Ω\1\18\0\19"
  .."\0\26\1\19\0\7\1\17@\9&\10Å\23Ç\29Å\4&\16‘Ï¸Ï\49\0\16¸Ï‹‰\16"
  .."ﬁ‰\48\1\50\19\54\55\18\18\51\50\22\21\20\6#\34&'&&#\34\3\6\7"
  .."\2\2#\34&\53\52\54\51\50\22\23\22\22\1âj\14\2\1\12æ Pd@\55*\57"
  .."\11\6\9\16k\14\4\4\17ΩƒOeD=!\48\15\9\11˛˙\2∞l\57\2\3\1ºTA\54"
  .."?&#\15H˝ï¡n˛!˛bSA\56?\29\28\17T\0\3\1\14\1’\3¡\5\0\10\0%\0)"
  .."\0d@\54\9\6\0\25\31\11\23\14\6\0(Û&\0Ì\23&Ò\6Ì\12\17 Ô\31Ó\28"
  .."Ì\17#ñ*&\31\20\0\23\9\3('\24\13\9j\11k\31\3j\20i*\16¸Ïƒ¸Ï\50"
  .."\50¿¿\17\18\57\57\17\18\57\49\0\16Ù‰¸ÙÏ\16ƒÓÌ÷Ó\16Ó\17\18\57"
  .."\18\57\17\57\17\18\57\48\1\34\6\21\20\22\51\50\54\53\53\55\17"
  .."#\53\6\6#\34&\53\52\54\51\51\53\52&#\34\6\7\53\54\54\51\50\22"
  .."\1!\21!\2¨ê|WHiÉèè\49ÉRÅñª¨∂wu\51}CDá?∏¨˝k\2ú˝d\4PDN@Mès\29="
  .."˛@pABàtÅå\4Z\92#!\127\28\28¨˝\12{\0\0\3\0Ù\1’\3›\5\0\11\0\23"
  .."\0\27\0\51@\28\26Û\24Ò\6Ì\18\0Ì\12ñ\28\25\15\9\24\21\3\9j\15"
  .."k\3j\21i\28\16¸Ï¸Ï\17\18\57\17\18\57\49\0\16ÙÏÙÏ¸Ï\48\1\34\6"
  .."\21\20\22\51\50\54\53\52&'\50\22\21\20\6#\34&\53\52\54\3!\21"
  .."!\2hfssfeusg™À ´™ À´\2§˝\92\5{úããöùàãúu‡ºªﬂﬂªº‡¸`{\0\0\1\0J\0"
  .."\0\4á\5¥\0\31\0>@#\24¯\8˜\30\18\14\3\1˘\16\0\2\30\27\14\17q\21"
  .."\30q\27\15r\21o\11p\0r\27o\5l \16ÙÏ‰ÙÏ‰\16‰\16‰\57\17\18\57\49"
  .."\0\47<Ó\23\50ˆÓ\48\51\53\51&\2\53\16\0\51\50\0\17\20\2\7\51\21"
  .."!\53\54\18\53\52\2#\34\2\21\20\18\23\21Jı{n\1 Ú\1!o{¯˛\49xÜ"
  .."¥öö≥Üx¨Ü\1 º\1\55\1o˛í˛»º˛ﬂÖ¨¨L\1IﬁÊ\1\9˛˜Êﬁ˛∑L¨\0\0\3\0)ˇ„\4"
  .."∞\4{\0\10\0\19\0C\0è@I=\55\15\48\12\18\3\54\11%\8\0\30C\11\1"
  System.VERA=System.VERA
  .."\31ã\30ç\27\8å\34\55ã\54ø\15\46\11∂\20\1¡\51\15å@:æ(\34ôD\2\5"
  .."\0\24%=\3\47\18\46\5\21\18M\47\0u\30\11M\20C\5M\54+sD\16ÙƒÏ¸"
  .."Ïƒ¸ƒÏ\50\18\57\17\18\23\57\17\18\57\49\0\16‰\50Ù<Ï\50Ù<Ï\50\16"
  .."ÙÓ\16˛<ÙÓ\17\18\57\18\57\17\57\17\18\23\57\17\18\57\48@\9\48"
  .."\53\48\54\48\55\48\56\4\93\1\53#\34\6\21\20\22\51\50\54\1\53"
  .."\52&#\34\6\29\1\5!\14\1\21\20\22\51\50\54\55\21\14\1#\34&'\14"
  .."\1#\34&\53\52\54;\1\53\52&#\34\6\7\53>\1\51\50\22\23>\1\51\50"
  .."\22\17\2\31\49©xYS\92J\1ÌMWWL\1Î˛\21\1\1epOÅ\50\55ÑGnï 'Öaú£"
  .."»øuc^\56Ñ>MÑ<\91|%!ÑYÆë\1∫HZqYaÖ\1è\52óÖàù+è\15#\34°ê\51\51¨"
  ..")+RNPP¨§´≥XxÄ+'®#!?@=BÌ˛Œ\0\0\3\0\47ˇ†\4ñ\4º\0\9\0\19\0+\0s@"
  ..">+,&\31\29\26\19\10\1\0\4\13)& \20\13\4*&\30\26\4å&\13å\26æ&"
  .."ô,+,*\20\23\16 \30#\19\10\1\0\4\7)\23\16\29\7\31\7\18#D\16\18"
  .."\23>,\16ÙÏ¸Ï¿\18\57\17\18\57\18\23\57\17\57\57\17\18\57\57\17"
  .."\57\49\0\16‰ÙÏ\16Ó\16¿\16¿\17\18\57\57\18\57\18\23\57\17\57\57"
  .."\17\18\57\48\1\1\22\22\51\50\54\53\52&'&&#\34\6\21\20\22\23\7"
  .."&&\53\16\18\51\50\22\23\55\23\7\22\22\21\16\2#\34&'\7'\3m˛\49"
  .."$eAçê\12H#cCãï\14\14ã')ˆÈdû<ì\93§*,ˆÍgù\57†\92\3\12˝—\47\47€"
  .."’\52oØ\48\46÷ \48tG†G√q\1\30\1\46\55\56∞M√B¡z˛·˛”;<∫L\0\0\2\0"
  .."¡ˇÂ\3›\5’\0!\0%\0Ç@G\11\10\9\8\7\5\12\6%\25\26\25\3\4\2\2\5%"
  .."\26\26\25B!\26\5\2\4\6\25\0\16ã\15ç\12\0\34Ü$\12ó\19ô$à&\6#\25"
  .."\22\9\31\5\0\3\29\1\26#\9)\22\15\29\3\1\15\34\30#&\16‘¸ƒ‘Ï\16"
  .."÷Ó\17\57\17\18\23\57\17\18\57\18\57\49\0\16‰ÙÏ\16˛Õ\16ÙÓ\18\57"
  .."\57\23\57\48KSX\7\16\4Ì\17\23\57\7\16\4Ì\17\23\57Y\34\1\51\21"
  .."\20\6\7\7\6\6\21\20\22\51\50\54\55\21\6\6#\34&\53\52\54\55\55"
  .."\54\54\53\52\53\54\53\19#\53\51\2%æ=TZ>\47ÉmN≤b^øh∫›C^XC&\2ƒ"
  .."  \4DöbâRY;X\49YnEDº\57\56¿°LÉ\92V@T?\1\4\23\19\1\14˛\0\2\2\4"
  .."\0\0\2œ\5’\0\3\0\9\0\30@\14\6\0Ü\1à\4\7\6\8\2\3\4\0\10\16‘<Ï"
  .."\50\57\57\49\0\47Ù¸Ã\48\1\53\51\21\3\17\19\51\19\17\2\4ÀÀ\21"
  .."°\21\4◊˛˛˚)\2è\1e˛õ˝q\0\0\1\0X\1s\4y\3^\0\5\0\24@\11\4†\2\0\6"
  .."\3\28\1\0'\6\16¸‘Ï\49\0\16‘ƒÏ\48\19!\17#\17!X\4!®¸á\3^˛\21\1"
  .."?\0\1\0;ˇŸ\4†\6†\0\10\0\47@\26\10\3\2\1\0\5\11\5\4\8\6\11\10"
  .."\9\8\7\4\3\2\7\5\0\11\5\1\11\16‘ƒ\18\57\17\23\57\49\0\16‘ƒ¿¿"
  System.VERA=System.VERA
  .."\18\23\57\48\19'%\19\1\51\21#\1#\3d)\1#€\1”î\47˛\6\127ˆ\2›}b"
  .."˝%\5øÉ˘º\3\57\0\1\0\0˛V\4∞\6\20\0#\0à@N\8\23\29\30\29\2\3\4\5"
  .."\6\5\1\7\23\30\30\29\17\16\15\14\13\5\18\12\23\25\26\25\11\23"
  .."\26\26\25B\25\12\19\10\7\30\1\26\10∂\8\19è\18˙\22∂\15\1è\0˙\4"
  .."∂!õ\15\28\8$\30\29\27\26\25\12\11\9\8\7\10\0\18\47Ã\23\57\49"
  .."\0\16ƒ\50ƒ¸ÏÙÏ\16ÓˆÓ\16Ó\50\18\57\57\17\18\57\57\48KSX\7\16\5"
  .."Ì\7\16\5Ì\17\23\57\7\16\5Ì\17\23\57\7\16\5ÌY\34\1\21&&#\34\6"
  .."\7\3!\21!\3\2\6#\34&'\53\22\22\51\50\54\55\19#\53!\19\54\54\51"
  .."\50\22\4∞$R,fs\18\45\1\47˛∏d+«∫\57f\46\49d\48`y\26u¸\1\19\49"
  .."\26∆î\49c\5§\28\29|Ç˛…è˝Ö˛ˆÊ\21\22§\31!ñó\2Øè\1J±…\18\0\2\0"
  .."X\1\49\4y\3√\0\27\0\55\0K@&\29' \49\48+\3\53\28\1\11\4\15\25"
  .."\11†\18\0\25†\14\4* †\53'†\46\28\56\49\48\28\0*\14\56\16‘<ƒ\50"
  .."\57\57\49\0\16‘<Ï‘Ï\50‹<¸‘<Ï\18\57\17\18\57\17\18\23\57\17\18"
  .."\57\48\1\21\6\6#\34'&'&&#\34\6\7\53\54\54\51\50\22\23\22\23\22"
  .."\51\50\54\19\21\6\6#\34'&'&&#\34\6\7\53\54\54\51\50\23\51\22"
  .."\23\22\51\50\54\4yKèOZq\22\11Mg\51OçINíS\53dK\10\22t\93FâJKè"
  .."OZq\22\11Sc\49NçJOíR`Ç\1\11\22t\93Dä\3√Ø;\55\51\10\4\34\24;@"
  .."Æ<\55\22 \4\11\54<˛–∞;\56\51\10\5$\23<AÆ>\55\55\5\10\55=\0\0"
  .."\2ˇ˙\0\0\4Ÿ\5è\0\3\0\6\0O@*\4i\5\4\2\3\2\6i\3\3\2\5i\0\1\0\4"
  .."i\6\4\1\1\0B\4\1\5˘\1˚\0\6\5\4\2\1\5\7\3\0\7\16‘Ã\17\23\57\49"
  .."\0\47‰Ï\17\57\48KSX\7\16\8Ì\7\16\5Ì\7\16\5Ì\7\16\8ÌY\34#\1\51"
  .."\9\2!\6\2\6—\2\8˝è˛ê\2·\5è˙q\4√˚È\0\0\2\0w\0ç\4\18\4#\0\6\0\13"
  .."\0\47@\23\9\2\11\4¸\7\0¨\14\2\12\5\9\0\10\7v\12\3\0v\5\14\16"
  .."‘¸<‘Ï\50\17\57\17\18\57\49\0\16Ù<Ï\50\57\57\48\1\21\1\1\21\1"
  .."\53\1\21\1\1\21\1\53\2L˛”\1\45˛+\3õ˛”\1\45˛+\4#ø˛Ù˛Ùø\1¢R\1¢"
  .."ø˛Ù˛Ùø\1¢R\0\0\2\0¡\0ç\4\92\4#\0\6\0\13\0\47@\23\12\5\10\3¸\7"
  .."\0¨\14\5\8\1\12\7\1v\3\0\8v\10\7\14\16‘<¸‘<Ï\18\57\17\18\57\49"
  .."\0\16Ù<Ï\50\57\57\48\1\1\21\1\53\1\1%\1\21\1\53\1\1\2á\1’˛+\1"
  .."\45˛”˛:\1’˛+\1\45˛”\4#˛^R˛^ø\1\12\1\12ø˛^R˛^ø\1\12\1\12\0\3\0"
  .."P\0\0\4\127\1\49\0\3\0\7\0\11\0#@\17\8\4\0¢\10\6\2\4\29\5\8\29"
  .."\9\1\29\0\12\16‘¸‘Ï‘Ï\49\0\47<<Ï\50\50\48\19\51\17#\1\51\17#"
  .."\1\51\17#P¸¸\3\51¸¸˛f¸¸\1\49˛œ\1\49˛œ\1\49˛œˇˇ\0%\0\0\4¨\7k\0"
  System.VERA=System.VERA
  .."'\0$\0\0\0\0\0\7\1\6\0\0\1uˇˇ\0%\0\0\4¨\7^\0'\0$\0\0\0\0\0\7"
  .."\1\5\0\0\1uˇˇ\0uˇ„\4\92\7^\0'\0\50\0\0\0\0\0\7\1\5\0\0\1u\0\2"
  .."\0H\0\0\4¡\5’\0\16\0\25\0;@\31\14ó\12\17\10ó\8à\23\0ó\12±\1\23"
  .."\17\8\2\20\15\11\30\24\9\13\0\45\20\30\5\26\16‹Ï¸ƒƒ‘Ï\50\18\57"
  .."\57\57\57\49\0\47ÏÏ\50ÙÏ\50\16Ó\48%\21! \2\17\16\18!!\21!\17"
  .."!\21!\17\1\34\6\17\16\22\51\51\17\4¡˝£˛ŸıÙ\1(\2R˛ö\1H˛∏˛˛±ãã"
  .."±=™™\1M\1ú\1°\1K™˛F™˝„\4ÅÊ˛§˛¶Â\4Å\0\3\0\14ˇ„\4∫\4{\0\10\0\22"
  .."\0\56\0i@\57\50\47\9\6\0\25\31\23& \11\56\23\0 ã\31ç\11\0∂\23"
  .."\28\11å#\23¡\17\6å\53\47æ)#ô\57\0\3\50&\24\9M\14u\31\3M\23C\20"
  .."M,s\57\16ÙÏ¸Ïƒ¸Ï\50\57\57\17\57\49\0\16‰\50Ù<Ï\50‰\16Ó\50\16"
  .."Ó\16ÙÓ\17\18\57\17\18\57\17\18\57\17\18\57\17\57\48\1\52\54\53"
  .."\52&#\34\6\21\21\1\50\54\53\16&#\34\6\17\16\22\1!\21\20\22\51"
  .."\50\54\55\21\6\6#\34&'\6\6#\34\2\17\16\18\51\50\22\23\54\54\51"
  .."\50\22\17\4\23\2PVWM˛¶fRPhgPP\3¨˛\21cpPÉ\47;}Jbì\48\52ÄTΩ™™Ω"
  .."YÄ\47%ÇWØê\2ë\11&\9ëáâû+˝Í®Ô\1#Æß˛Û˛Ûß\1áT£ê\53\51¨+)CBDA\1\20"
  .."\1\56\1\56\1\20>A>AÌ˛Œ\0\1\0\0\1Ï\4—\2y\0\3\0\16∂\2∂\0˝\4\1\0"
  .."\47∆\49\0\16¸Ï\48\17!\21!\4—˚\47\2yç\0\0\1\0\0\1Ï\4—\2y\0\3\0"
  .."\15µ\2∂\0\4\1\0\47ƒ\49\0\16‘Ï\48\17!\21!\4—˚\47\2yç\0\2\0”\3"
  .."«\3˛\6\20\0\5\0\11\0%@\18\6\0£\9\3µ\12\3\4\0\29\1\7\29\6\9\10"
  .."\12\16‘Ã‘Ï‘¸‘Ã\49\0\16¸<Ï\50\48\1#\53\19\51\3\5#\53\19\51\3\3"
  .."ú¸ƒöb˛\53˛«ôb\3«œ\1~˛Çœœ\1~˛Ç\0\2\0”\3«\3¸\6\20\0\5\0\11\0'@"
  .."\19\9\3£\6\0µ\12\9\10\6\3\4\1\29\0\6\29\7\12\16‘Ï‘Ï‘Ã\16‘Œ\49"
  .."\0\16¸<Ï\50\48\1\51\21\3#\19%\51\21\3#\19\3\0¸≈ôb˛\53¸ƒöb\6\20"
  .."Œ˛Å\1\127ŒŒ˛Å\1\127\0\1\1œ\3«\3\45\6\20\0\5\0\24@\11\0£\3µ\6"
  .."\3\4\0\29\1\6\16‘¸‘Ã\49\0\16¸Ï\48\1#\53\19\51\3\2À¸ƒöb\3«œ\1"
  .."~˛Ç\0\0\1\1œ\3«\3\45\6\20\0\5\0\24@\11\3£\0µ\6\3\4\1\29\0\6\16"
  .."‘Ï‘Ã\49\0\16¸Ï\48\1\51\21\3#\19\2\49¸≈ôb\6\20Œ˛Å\1\127\0\0\3"
  .."\0X\0ñ\4y\4o\0\3\0\7\0\11\0'@\19\2˛\0\4˛\6\8†\0\10\12\9\5\1w"
  .."\8\4\0\12\16‘<ƒ¸<ƒ\49\0\16‘ƒ¸‘Ï\16Ó\48\1\51\21#\17\51\21#\5!"
  .."\21!\1Óıııı˛j\4!˚ﬂ\1ãı\3Ÿˆ¢™\0\0\2\0u˛#\4\92\6u\0\3\0\7\0\34"
  .."@\17\2\6\0\8\4\6\8\6\4\3\2\1\0\6\5\7\8\16‘Ã\23\57\49\0\16‘Ã\17"
  .."\57\18\57\48\9\7\2h˛\127\1Å\1Å˛\127\1Ù˛\12˛\13\5Å¸œ¸«\3\57\4"
  System.VERA=System.VERA
  .."%˚€˚”\4\45ˇˇ\0h˛V\4Å\6\16\0'\0\92\0\0\0\0\0\7\0é\0\0\0\0ˇˇ\0"
  .."%\0\0\4¨\7N\0'\0<\0\0\0\0\0\7\1\3\0\0\1u\0\1\0fˇB\4\55\5’\0\3"
  .."\0\24@\11\2\0à\4\1\30\0\2\30\3\4\16‘Ï‘Ï\49\0\16Ùƒ\48\1\51\1#"
  .."\3yæ¸Óø\5’˘m\0\2\0Õ\0√\4L\4B\0\11\0\47\0Å@\26 \22\27\23\14(\45"
  .."\13\24\30\27\9*\12\45'!\21\15\4\3\9ˇ\31\23\27∏\1\0@'\3ˇ)\13\45"
  .."\48\31)$ \13\23\18\14!'$\6\15\21\18*\30\24\12\4\6\0x\22\14\18"
  .."y\6x( $\48\16‘ƒ\50Ï¸ƒ\50Ï\17\23\57\17\57\57\17\18\57\57\17\18"
  .."\57\57\17\18\57\57\49\0\16‘ƒ\50Ï¸ƒ\50Ï\17\23\57\18\57\57\17\18"
  .."\57\57\17\18\57\57\17\18\57\57\48\1\52&#\34\6\21\20\22\51\50"
  .."\54\3\55\23\7\22\22\21\20\6\7\23\7'\6\6#\34&'\7'\55&&\53\52\54"
  .."\55'\55\23\54\54\51\50\22\3d|\91Z}}Z\91|\24¶Z¶\30\29\30\31®^"
  .."¶\46\91\50\48`\48§\92¶\31\29\31\31®^¶\46\91\51\46^\2ÉZ{{Z\92"
  .."}~\1t¶\93¶\49\93\48\50\91\45¶^ß\31\30\29\28£Z¶\51\93\46\50\93"
  .."\45¶_®\31\30\29\0\0\1\1Z\0ç\3\47\4#\0\6\0\26@\12\2\4¸\0¨\7\2"
  .."\3\0v\5\7\16‘Ï\50\57\49\0\16ÙÏ\57\48\1\21\1\1\21\1\53\3\47˛”"
  .."\1\45˛+\4#ø˛Ù˛Ùø\1¢R\0\1\1§\0ç\3y\4#\0\6\0\26@\12\5\3¸\0¨\7\5"
  .."\1v\3\0\7\16‘<Ï\57\49\0\16ÙÏ\57\48\1\1\21\1\53\1\1\1§\1’˛+\1"
  .."\45˛”\4#˛^R˛^ø\1\12\1\12\0\0\2\0#\0\0\4\55\6\20\0\3\0\25\0N@"
  .."*\20\9\22\2\18\14∂\10\5å\4\2ƒ\0õ\4õ\10¬\16\12\6\25\9\4\13\0\6"
  .."\1\4\15\9\6\11\1J\19E\21\17E\26\16Ù<‰Ï\50¸<ƒ\16Ó\50\17\18\57"
  .."\57\49\0\47<ÊÏ˛Ó\16Ó\16Ó\50\18\57\57\57\48\1\51\21#'\21#\34\6"
  .."\21\21!\17#\17!\17#\17#\53\51\53\52\54\51\3\127∏∏w¥cM\2ì∏˛%∏"
  .."……©≥\6\18ÈÎôQge˚¢\3—¸\47\3—èN∏Æ\0\1\0#\0\0\4\55\6\20\0\21\0B"
  .."@#\16\7\18\3\14\10∂\8\3å\0õ\8¬\12\1\4\21\9\7\2\6\0\9\11\7\6\0"
  .."J\15E\17\13E\22\16Ù<‰Ï¸<ƒ\16Ó\17\18\57\57\49\0\47<Ê˛Ó\16Ó\50"
  .."\18\57\57\57\48\1\17#\17!\34\6\21\21!\21!\17#\17#\53\51\53\52"
  .."\54\51\4\55∏˛’cM\1%˛€∏……©≥\6\20˘Ï\5{Qgeç¸\47\3—èN∏Æ\0\1\0¢ˇ;"
  .."\4\47\5’\0\19\0<@\31\18\6À\0\16\8À\14\10\12\4\0\2 \12à\20\15"
  .."\0R\17\13\1Q\9\5R\11\7\3\20\16‘<<Ï\50¸<<Ï\50\49\0\16‰Ùƒ\50\16"
  .."‘<Ó\50\16Ó\50\48%!\17#\17!\53!\17!\53!\17\51\17!\21!\17!\4\47"
  .."˛í±˛í\1n˛í\1n±\1n˛í\1nﬂ˛\92\1§ö\2\31ô\1§˛\92ô˝·\0\1\1È\2\47\2"
  .."Â\3`\0\3\0\21π\0\2\1\1µ\0\4\1\29\0\4\16‘Ï\49\0\16‘Ï\48\1\51\17"
  System.VERA=System.VERA
  .."#\1È¸¸\3`˛œ\0\0\1\1ì˛·\2Ú\1\47\0\5\0\26≤\3£\0∏\1\1∂\6\3\4\1\29"
  .."\0\6\16‘Ï‘Ã\49\0\16¸Ï\48\1\51\21\3#\19\1ˆ¸≈öc\1\47œ˛Å\1\127\0"
  .."\0\2\0”˛·\3¸\1\47\0\5\0\11\0*¥\9\3£\6\0∏\1\1@\13\12\9\10\6\3"
  .."\4\1\29\0\6\29\7\12\16‘Ï‘Ï‘Ã\16‘Œ\49\0\16¸<Ï\50\48\1\51\21\3"
  .."#\19%\51\21\3#\19\3\0¸≈ôb˛\53¸ƒöb\1\47œ˛Å\1\127œœ˛Å\1\127\0\0"
  .."\7\0\0\0\0\4—\5ò\0\3\0\15\0\27\0'\0\51\0?\0K\0t@\14\3\2%\31\1"
  .."\49\0=\13»\19\31»\49∏\1\2µ%»+ëC\19∏\1\2@&\55\7»I\25\3F\2:\52"
  .."\1(\0\28\16:PFz\52P@\10P\22z\4P\16\34P\46z\16\28P@(\47ƒÏƒÙÏ\16"
  .."ÓˆÓ\16ÓˆÓ\17\18\57\18\57\17\18\57\17\57\49\0\47<Ó\50Ó\50ˆÓ˛Ó"
  .."\16Ó\50\57\18\57\17\18\57\57\48\19'\1\23\1\20\22\51\50\54\53"
  .."\52&#\34\6\7\52\54\51\50\22\21\20\6#\34&\19\20\22\51\50\54\53"
  .."\52&#\34\6\7\52\54\51\50\22\21\20\6#\34&\1\20\22\51\50\54\53"
  .."\52&#\34\6\7\52\54\51\50\22\21\20\6#\34&H%\4\20'¸H_EDbcCE_y•"
  .."xx¶ßwy§LaEEacCEay¶yx¶¶xy¶\3\12aEF`bDEay¶yxßßxy¶\2\55a\1ü`˝JG"
  .."acECcaEy•¶xy®¶\3”EaaECcaExßßxy®ß˝\34GaaGCcaEx¶¶xy®ßˇˇ\0%\0\0"
  .."\4¨\7m\0'\0$\0\0\0\0\0\7\1\7\0\0\1uˇˇ\0≈\0\0\4N\7m\0'\0(\0\0"
  .."\0\0\0\7\1\7\0\18\1uˇˇ\0%\0\0\4¨\7k\0'\0$\0\0\0\0\0\7\1\4\0\0"
  .."\1uˇˇ\0≈\0\0\4N\7N\0'\0(\0\0\0\0\0\7\1\3\0\18\1uˇˇ\0≈\0\0\4N"
  .."\7k\0'\0(\0\0\0\0\0\7\1\6\0\18\1uˇˇ\0…\0\0\4\6\7k\0'\0,\0\0\0"
  .."\0\0\7\1\4\0\0\1uˇˇ\0…\0\0\4\6\7m\0'\0,\0\0\0\0\0\7\1\7\0\0\1"
  .."uˇˇ\0…\0\0\4\6\7N\0'\0,\0\0\0\0\0\7\1\3\0\0\1uˇˇ\0…\0\0\4\6\7"
  .."k\0'\0,\0\0\0\0\0\7\1\6\0\0\1uˇˇ\0uˇ„\4\92\7k\0'\0\50\0\0\0\0"
  .."\0\7\1\4\0\0\1uˇˇ\0uˇ„\4\92\7m\0'\0\50\0\0\0\0\0\7\1\7\0\0\1"
  .."uˇˇ\0uˇ„\4\92\7k\0'\0\50\0\0\0\0\0\7\1\6\0\0\1uˇˇ\0ìˇ„\4=\7k"
  .."\0'\0\56\0\0\0\0\0\7\1\4\0\0\1uˇˇ\0ìˇ„\4=\7m\0'\0\56\0\0\0\0"
  .."\0\7\1\7\0\0\1uˇˇ\0ìˇ„\4=\7k\0'\0\56\0\0\0\0\0\7\1\6\0\0\1u\0"
  .."\1\0≤\0\0\4D\4`\0\9\0\34@\18\8∂\0¬\6\2∂\4\3L\1\6\5L\0K\7\10\16"
  .."‘‰Ï¸Ï\49\0\47Ï\50ÙÏ\48\1!\17!\21!\53!\17!\1\0\1◊\1m¸n\1m˛·\4"
  .."`¸\47èè\3B\0\1\1)\4Ó\3®\6f\0\6\0\55@\12\4\5\2∫\0π\7\4\2\11\6"
  .."\7\16‘Ï\57\49\0\16ÙÏ\50\57\48\0K∞\9TK∞\14T\91XΩ\0\7ˇ¿\0\1\0\7"
  .."\0\7\0@\56\17\55\56Y\1\51\19#'\7#\2\31ìˆãµ¥ã\6f˛àıı\0\1\1\31"
  .."\5\29\3≤\6\55\0\27\0ª@!\0\18\7\14\11\4\1\18\7\15\11\4\18Ã\25"
  System.VERA=System.VERA
  .."\7\4Ã\21\11\28\15\1\14\0\7\21P\22\7P\8\28\16‘Ï‘Ï\17\57\57\57"
  .."\57\49\0\16‘<¸‘<Ï\17\18\57\17\18\57\17\18\57\17\18\57\48\0K∞"
  .."\9TK∞\12T\91XΩ\0\28ˇ¿\0\1\0\28\0\28\0@\56\17\55\56Y\0K∞\15TX"
  .."Ω\0\28\0@\0\1\0\28\0\28ˇ¿\56\17\55\56Y@?\9\0\12\10\12\11\12\12"
  .."\11\15\11\16\15\17\15\18\15\19\15\20\15\21\15\22\15\23\9\27\25"
  .."\0\25\1\27\10\27\11\27\12\27\13\27\14\27\15\27\16\27\17\27\18"
  .."\27\19\31\20\31\21\31\22\26\23\25\27\31\1\93\1'\46\1#\34\6\7"
  .."#>\1\51\50\22\31\1\30\1\51\50\54\55\51\14\1#\34&\2d\57\21!\14"
  .."&$\2|\1f\91'@%\57\21!\13'$\1}\1f\91'@\5Z\55\20\19JQÜî\28!\55"
  .."\20\19JQÜî\28\0\0\1\1=\5b\3ì\5ˆ\0\3\0\17∂\2∂\0\4\1\0\4\16‘Ã\49"
  .."\0\16‘Ï\48\1!\21!\1=\2V˝™\5ˆî\0\1\1\47\5)\3¢\6H\0\13\0\56π\0"
  .."\11\1\3@\12\4\7\0π\14\7P\8\1P\0\14\16‘Ï‹Ï\49\0\16Ù<‘Ï\48\0K∞"
  .."\9TXΩ\0\14ˇ¿\0\1\0\14\0\14\0@\56\17\55\56Y\1\51\30\1\51\50\54"
  .."\55\51\14\1#\34&\1\47w\11`WU`\14w\11ûëêû\6HLJJLèêê\0\1\2\2\5"
  .."D\2œ\6\16\0\3\0\54@\9\2ﬁ\0›\4\1a\0\4\16‘Ï\49\0\16ÙÏ\48\0K∞\10"
  .."TK∞\13T\91K∞\14T\91XΩ\0\4\0@\0\1\0\4\0\4ˇ¿\56\17\55\56Y\1\51"
  .."\21#\2\2ÕÕ\6\16Ã\0\0\2\1V\4·\3{\7\6\0\11\0\23\0W≤\15»\9∏\1\4"
  .."@\12\21»\3\24\12P\0{\18P\6\24\16‘ÏÙÏ\49\0\16‘ÏÙÏ\48\0K∞\9TK∞"
  .."\12T\91XΩ\0\24ˇ¿\0\1\0\24\0\24\0@\56\17\55\56Y\1K∞\9TXΩ\0\24"
  .."\0@\0\1\0\24\0\24ˇ¿\56\17\55\56Y\1\20\6#\34&\53\52\54\51\50\22"
  .."\7\52&#\34\6\21\20\22\51\50\54\3{ütsüüstü{X@@WW@@X\5Ùs††ssüü"
  .."s?XW@AWX\0\0\1\1ã˛u\3)\0\0\0\19\0'≥\9\6\10\13∫\1\6\0\6\1\5@\9"
  .."\0\9\16\19\0\16|\3\20\16‘Ï‘Ã\16ƒ\49\0\47ˆ˛≈\18\57\48!\22\22\21"
  .."\20\6#\34&'\53\22\22\51\50\54\53\52&'\2º\56\53xv\45W,\34K\47"
  ..":=,,>i\48Y\91\12\12É\17\15\48\46\30W=\0\2\1X\4Ó\4\23\6f\0\3\0"
  .."\7\0Z@\17\6\2∫\4\0π\8\0\7\3\4\1\5\7\1\3\8\16‘‹‘Ã\17\57\17\18"
  .."\57\49\0\16Ù<Ï\50\48\0K∞\9TK∞\14T\91XΩ\0\8ˇ¿\0\1\0\8\0\8\0@\56"
  .."\17\55\56Y\1K∞\9TXΩ\0\8\0@\0\1\0\8\0\8ˇ¿\56\17\55\56Y\1\51\3"
  .."#\1\51\3#\2\23™‡â\2\12≥¯á\6f˛à\1x˛à\0\1\1§˛u\3\25\0\0\0\19\0"
  .."\34≥\11\14\10\7∏\1\6@\9\14\0\1\0\10\4|\17\20\16‘Ïƒ‘Ã\49\0\47"
  .."‘¸ƒ\18\57\48!\51\6\6\21\20\22\51\50\54\55\21\6\6#\34&\53\52\54"
  .."\2\16w\45+\55\54 >\31&D\30zs\53=X\31\46\46\15\15Ö\10\10W\93\48"
  System.VERA=System.VERA
  .."i\0\1\1)\4Ó\3®\6f\0\6\0\55@\12\3\0∫\4\1π\7\3\5\11\1\7\16‘Ï\57"
  .."\49\0\16Ù<Ï\57\48\0K∞\9TK∞\14T\91XΩ\0\7ˇ¿\0\1\0\7\0\7\0@\56\17"
  .."\55\56Y\1\3\51\23\55\51\3\2\31ˆã¥µãˆ\4Ó\1xıı˛à\0\1ˇˆ\0\0\4s\5"
  .."’\0\13\0\55@\30\12\11\10\4\3\2\6\0\6ó\0à\8\3\4\7\1\11\14\0\12"
  .."\5\1\30\7\49\9\0\52\14\16¸<ÏÏ\50\46\17\18\57\17\18\57\57\49\0"
  .."\47‰Ï\17\23\57\48\19\51\17%\23\1\17!\21!\17\7'\55◊À\1;N˛w\2—"
  .."¸dëP·\5’˝ò€o˛Ó˝„™\2;jnû\0\0\1\0L\0\0\4\10\6\31\0\21\0>@!\20\19"
  .."\18\12\11\10\6\9\0\3\14∂\16≈\3∂\5\11\12\22\15\19\3\6\20\4\17"
  .."\0\6\15\13\9\22\16‘<Ã¸<Ã\50\57\57\57\17\18\57\57\49\0\47Ï¸Ï\17"
  .."\57\57\23\57\48\1\20\22\51\51\21#\34&\53\17\5'\1\17!\53!\17%"
  .."\23\1\2\127\91Y◊È•µ˛’P\1{˛Ÿ\1ﬂ\1;P˛u\1ñ|~ú‘¬\1$—o\1\8\2\47ê˝"
  .."æ€n˛Ìˇˇ\0ãˇ„\4J\7m\0'\0\54\0\0\0\0\0\7\1\8\0\0\1uˇˇ\0’ˇ„\4\6"
  .."\6f\0'\0V\0\0\0\0\0\7\0‡\0\0\0\0ˇˇ\0ú\0\0\4ë\7m\0'\0=\0\0\0\0"
  .."\0\7\1\8\0\0\1uˇˇ\0À\0\0\4\16\6f\0'\0\93\0\0\0\0\0\7\0‡\0\0\0"
  .."\0\0\2\2\18˛¢\2æ\5ò\0\3\0\7\0!º\0\5\1\7\0\4\0\0\1\7∑\1\8\4\0"
  .."\4\6\2\8\16‘<Ï\50\49\0\16‘Ï‘Ï\48\1\17#\17\19\17#\17\2æ¨¨¨\5ò"
  .."˝\10\2ˆ¸\0˝\10\2ˆ\0\2\0\8\0\0\4N\5’\0\12\0\25\0;@!\23\8∂\10\19"
  .."ó\0à\13ó\21\10\6\19\13\6\0\4\22\20\16\50\3\49\9\48\24\20\30\11"
  .."\7\48\26\16¸<Ï\50Ï¸Ï\16ƒ\23\57\49\0\47∆\50ÓˆÓ\16Ó\50\48\1 \0"
  .."\17\16\0!!\17#\53\51\17\1\50\54\17\16&!#\17!\21!\17\1¥\1V\1D"
  .."˛ª˛´˛—}}\1\47ˇ …ˇ\0`\1\8˛¯\5’˛î˛Ä˛Ç˛ï\2≈ï\2{˙—˚\1H\1K˚˛+ï˝·\0"
  .."\0\2\0âˇ„\4H\6\20\0\26\0)\0ã@O\18\23\19\18\1\0\13\14\15\16\4"
  .."\17\23\0\1\0\22\23\23\24\23\21\23\20\21\24\24\23B\26\25\24\21"
  .."\20\19\6\22\15\30\18\0\22\30å\12$å\6ô\12\22õ*\18\21\24\3'\20"
  .."\19\22\3!\9\26\25\3\15\0!'\18\3D!\18\9>*\16ÙÏ¸Ï\17\57\57\17\57"
  .."\57\17\18\23\57\17\23\57\49\0\16ÏÃÙÏ\16Ó\18\57\57\18\57\18\23"
  .."\57\48KSX\7\16\8Ì\7\16\5Ì\7\16\5Ì\23\57\7\8ÌY\34\1\22\18\21\16"
  .."\2#\34\2\17\16\18\51\50\22\23&&'\5'\55'\51\23%\23\3&&#\34\6\21"
  .."\20\22\51\50\54\53\52&\2Õ≈∂˚Â‰˚˚‡\34#\15!H&˛È\30Ì∂€\127\1!!Æ"
  .."#R\45íôîàâî:\5\47‘˛Ñ»˛Ù˛ÿ\1(\1\12\1\9\1(\2\2\45Y,\92bP»ë^b˛\23"
  .."\13\13“«ƒ‘‘ƒnÀˇˇ\0%\0\0\4¨\7k\0'\0<\0\0\0\0\0\7\1\4\0\0\1uˇˇ"
  .."\0h˛V\4Å\6f\0'\0\92\0\0\0\0\0\7\0ç\0\0\0\0\0\2\0…\0\0\4ç\5’\0"
  System.VERA=System.VERA
  .."\8\0\21\0\52µ\1ó\18\0ó\11∏\1\8@\19\9à\20\8\2\18\12\0\5\50\15"
  .."\56\19\10\0\30\9\51\22\16¸Ï\50\50¸Ï\17\57\57\57\57\49\0\47Ù¸"
  .."Ï‘Ï\48\1\17\51\50\54\53\52&#\1\51\17\51 \22\21\20\6!#\17#\1ì"
  .."Íûùùû˛L ˛\1\4¯¯˛¸˛ \4!˝ÛÑÉÉÉ\1¥˛Ú“⁄€—˛ë\0\0\2\0æ˛V\4T\6\31\0"
  .."\16\0\28\0\51@\28\5\0\26\20å\8\26å\14ô\8æ\1√\3≈\29\17\18\11G"
  .."\23\4\0\6\2F\29\16ÙÏ\50\50¸Ï\49\0\16Ï‰‰ÙÏ\16Ó\17\57\57\48%\17"
  .."#\17\51\17\54\54\51\50\18\17\16\2#\34&\1\52&#\34\6\21\20\22\51"
  .."\50\54\1wππ\46ôdÀÁË fô\1áÖÜääÜÖáç˝…\7…˝≤SW˛∆˛Í˛Ô˛…W\1ı÷⁄€’‘"
  .."‹⁄\0\1\0X\2\45\4y\2◊\0\3\0\17∂\0†\2\4\1\0\4\16‘ƒ\49\0\16‘Ï\48"
  .."\19!\21!X\4!˚ﬂ\2◊™\0\0\1\0ñ\0Æ\4;\4T\0\11\0\46@\28\10\8\7\6\4"
  .."\2\1\0\8\11\9\5\3\12\11\10\9\8\7\5\4\3\1\9\6\2\0\12\16‘<Ã\23"
  .."\57\49\0\16‘<Ã\50\23\57\48\19\1\1\55\1\1\23\1\1\7\1\1ñ\1^˛¢t"
  .."\1^\1_t˛¢\1\92t˛£˛§\1%\1\92\1^u˛¢\1^u˛¢˛§w\1^˛¢\0\0\1\1X\2ú\3"
  .."ì\5ﬂ\0\10\0\57A\11\0\7\0\0\1\9\0\9\0\3\1\9\0\4\0\9\1\10\0\2\1"
  .."\9@\13\5ñ\11\8a\6W\3}\0a\1\11\16‘ÏÏ¸Ï\49\0\16ÙÏ‰‘Ï\16Ó\50\48"
  .."\1\51\17\7\53\55\51\17\51\21!\1jÕﬂÂäÃ˝◊\3\10\2c)t'˝+n\0\0\1\1"
  .."B\2ú\3}\5\0\24\0a@\19\0W\4\5\4\22\23\2\21\24W\5\5\4B\5\24\14"
  .."\0A\9\1\9\0\2\0\14\1\9\0\15\0\2\1\10\0\11\1\9@\14\18ñ\25\5\0"
  .."\24\14\8\127\1\21\14\3\25\16‘ƒ‘ƒÏ\17\57\57\57\49\0\16ÙÏ‰‘Ï\16"
  .."Ó\17\57\57\48KSX\7\16\4Ì\17\23\57\7\16\5ÌY\34\1!\21!\53\55\54"
  .."\54\53\52&#\34\6\7\53\54\54\51\50\22\21\20\6\7\1„\1ö˝≈ÁeQdR\49"
  .."q?Ay;é¨Jw\3\14rn‚az\51=L$$}\28\28Ök\57wu\0\0\1\1F\2ç\3ú\5\0"
  .."(\0\92A\20\0\0\0\19\1\9\0\21\0\10\1\9\0\9\1\11\0\21\0\13\1\9"
  .."\0\6\0\31\1\9\0 \1\11\0\6\1\10\0\28\1\9@\19#ñ)\22\19\13\0\3\20"
  .."\25\127&\16\127\3\31\20\9)\16‘ƒƒ‘Ï‘Ï\17\23\57\57\49\0\16ÙÏ‰Ù"
  .."Ï\16Ó∆ˆÓ\16Ó\57\48\1\22\22\21\20\6#\34&'\53\22\22\51\50\54\53"
  .."\52&##\53\51\50\54\53\52&#\34\6\7\53\54\54\51\50\22\21\20\6\2"
  .."€^cæ±:r;Eq\45evnmBJ\93b`W,p;Eu\50ë®X\4`\21lP|Ü\21\20y\27\26Q"
  .."DJLl?<\56?\24\23y\17\18vcG\93ˇˇ\0\27˛Ú\4Z\6{\0'\0˛˛\0ú\0'\1"
  .."\9\0\0\0\0\0\7\1\10\0∏¸Vˇˇ\0\27˛Ú\4Z\6{\0'\0˛˛\0ú\0'\1\9\0\0"
  .."\0\0\0\7\0Ò\0…¸Vˇˇ\0\27˛Ú\4Z\6å\0'\0Úˇ\29\0ú\0'\1\9\0\0\0\0\0"
  .."\7\1\10\0∏¸Vˇˇ\0fˇ„\4P\7m\0'\0*\0\0\0\0\0\7\1\11\0\0\1uˇˇ\0{"
  System.VERA=System.VERA
  .."˛H\4\18\6H\0'\0J\0\0\0\0\0\7\0⁄\0\0\0\0ˇˇ\0…\0\0\4\6\7P\0'\0"
  ..",\0\0\0\0\0\7\1\12\0\0\1uˇˇ\0ã˛u\4J\5\0'\0\54\0\0\0\0\0\7\0"
  .."›\0\0\0\0ˇˇ\0’˛u\4\6\4{\0'\0V\0\0\0\0\0\7\0›\0\0\0\0ˇˇ\0ãˇ„\4"
  .."\49\7k\0'\0&\0\0\0\0\0\7\1\4\0Z\1uˇˇ\0√ˇ„\4%\6f\0'\0F\0\0\0\0"
  .."\0\7\0ç\0Z\0\0ˇˇ\0ãˇ„\4\49\7m\0'\0&\0\0\0\0\0\7\1\8\0Z\1uˇˇ\0"
  .."√ˇ„\4%\6f\0'\0F\0\0\0\0\0\7\0‡\0Z\0\0\0\2\0{ˇ„\4—\6\20\0\24\0"
  .."$\0H@\9\13\0\34\28\7\3Á\9\1∏\1\12@\28\34å\22\28å\16ô\22æ\5õ\11"
  .."\2\31\12\4\3\0\6\8\10\6G\25\18\19H%\16ÙÏ¸<ƒ¸\23<ƒ\49\0\47Ï‰Ù"
  .."Ï\16Ó˝<Ó\50\17\18\57\57\48\1\17!\53!\53\51\21\51\21#\17#\53\6"
  .."\6#\34\2\17\16\18\51\50\22\1\20\22\51\50\54\53\52&#\34\6\3Z˛"
  .."œ\1\49∏øø∏\46ôdÀÈÍ eö˛\15àÖÖããÖÖà\3—\1\53yïïy˙˙çSW\1;\1\21\1"
  .."\17\1\55W˛\11÷⁄‹‘’€⁄\0\0\1\1d\1ﬂ\3m\2É\0\3\0\17∂\0†\2\4\1\0\4"
  .."\16‘ƒ\49\0\16‘Ï\48\1!\21!\1d\2\9˝˜\2É§\0\1\1È\2\47\2Â\3`\0\3"
  .."\0\21π\0\2\1\1µ\0\4\1\29\0\4\16‘Ï\49\0\16‘Ï\48\1\51\17#\1È¸¸"
  .."\3`˛œ\0\0\1\0%ˇ„\4%\5\0\51\0p@<\13\0Á\49\15&\24Á\22\31≥ ≤\28"
  .."ó(\22#\7≥\6≤\10ó\3ñ#ô\52\51('\49)\45\24\22\16\3\19\15\23\14&"
  .."\0\45\25\13\23\19\14\50'\19\30\31\6\23\45\52\16‘ƒƒ\50Ïƒ\50ƒ\17"
  .."\18\57\57\18\57\57\17\18\57\17\23\57\18\57\57\17\57\57\49\0\16"
  .."‰ÙÏÙÏ\16∆\50ÓˆÓ\16Ó\50’<Ó\50\48\19\18\0\51\50\22\23\21&&#\34"
  .."\6\7!\7!\6\6\21\20\22\23!\7!\22\22\51\50\54\55\21\6\6#\34\0\3"
  .."#\55\51&'&\53\52\55\54\55#\55”\48\1\18ﬂTìJBüNíÆ\24\1·\49˛F\2"
  .."\1\1\1\1i\49˛”\23ÆìOùCHîU‚˛Ì,Æ\49u\1\1\2\2\1\1¶\49\3¥\1\27\1"
  .."!(*œ=D–Ãl\20\45\46\15&\23nÀ—C>œ*(\1 \1\28n\12\20\45\15\18\47"
  .."\19\11l\0\2\1?\5\14\3ë\5Ÿ\0\3\0\7\0Q@\13\4\0ﬁ\6\2\8\5a\4\1a\0"
  .."\8\16‘¸‘Ï\49\0\16‘<Ï\50\48\0K∞\14TXΩ\0\8\0@\0\1\0\8\0\8ˇ¿\56"
  .."\17\55\56Y\1K∞\14TK∞\13T\91XΩ\0\8ˇ¿\0\1\0\8\0\8\0@\56\17\55\56"
  .."Y\1\51\21#%\51\21#\1?ÀÀ\1à  \5ŸÀÀÀ\0\1\1€\4Ó\3Z\5ˆ\0\3\0kµ\0"
  .."\2\4\1\3\4\16‘ƒ\49\0\16‘ƒ\48\0K∞\12TXΩ\0\4ˇ¿\0\1\0\4\0\4\0@\56"
  .."\17\55\56Y\0K∞\14TXΩ\0\4\0@\0\1\0\4\0\4ˇ¿\56\17\55\56Y@&\15\0"
  .."\15\1\10\2\10\3\31\0\31\1\31\2\31\3\47\0\47\1\47\2\47\3\12\15"
  .."\0\15\1\31\0\31\1\47\0\47\1\6\93\1\93\1\51\3#\2†∫Âö\5ˆ˛¯\0\1"
  .."\1\31\5\14\3≤\5È\0\29\0—@\30\22\16\15\3\19\12\7\1\0\3\8\4Ã\23"
  System.VERA=System.VERA
  .."\12\19Ã\27\8\30\16\1\15\0\7\22\24\7\9\30\16‘ƒ‘ƒ\17\57\57\57\57"
  .."\49\0\16‘<¸‘<Ï\17\23\57\17\18\23\57\48\0K∞\14TK∞\17T\91XΩ\0\30"
  .."\0@\0\1\0\30\0\30ˇ¿\56\17\55\56Y@t\9\0\9\1\15\11\15\12\15\13"
  .."\13\14\15\15\15\16\15\17\15\18\15\19\15\20\15\21\15\22\15\23"
  .."\15\24\11\25\26\0\26\1\29\11\29\12\29\13\30\14\31\15\31\16\31"
  .."\17\31\18\31\19\31\20\31\21\31\22\31\23\31\24!\15\1\15\2\15\3"
  .."\15\4\15\5\15\11\15\12\15\13\15\21\15\22\15\23\15\24\31\1\31"
  .."\2\31\3\31\4\31\5\31\11\31\12\31\13\31\21\31\22\31\23\31\24\24"
  .."\93\1\93\1'\46\1#\34\6\29\1#\52\54\51\50\22\31\1\30\1\51\50\54"
  .."=\1\51\14\1#\34&\2d\57\25\31\12#(}gU$=\49\57\22#\15\31(}\2fT"
  .."\34<\5\57!\14\11\50\45\6ev\16\27\30\13\12\51)\6dw\16\0\1\1y\4"
  .."Ó\2ˆ\5ˆ\0\3\0iµ\0\1\4\1\3\4\16‘ƒ\49\0\16‘ƒ\48\0K∞\12TXΩ\0\4ˇ"
  .."¿\0\1\0\4\0\4\0@\56\17\55\56Y\0K∞\14TXΩ\0\4\0@\0\1\0\4\0\4ˇ¿"
  .."\56\17\55\56Y\1K∞\14TXΩ\0\4\0@\0\1\0\4\0\4ˇ¿\56\17\55\56Y@\13"
  .."\15\0\15\3\31\0\31\3\47\0\47\3\6\0\93\1\19#\3\2\49≈ö„\5ˆ˛¯\1"
  .."\8\0\1\1\55\4Ó\3ö\5¯\0\6\0\93@\9\4\0\5\2\7\4\2\6\7\16‘ƒ\57\49"
  .."\0\16‘<ƒ\57\48\0K∞\12TXΩ\0\7ˇ¿\0\1\0\7\0\7\0@\56\17\55\56Y\0"
  .."K∞\14TXΩ\0\7\0@\0\1\0\7\0\7ˇ¿\56\17\55\56Y@\19\15\0\15\1\12\4"
  .."\31\0\31\1\28\4\47\0\47\1,\4\9\93\1\51\19#'\7#\2\10Ω”å¶•å\5¯"
  .."˛ˆ≤≤\0\1\1\55\4Ó\3ö\5¯\0\6\0i@\9\3\4\1\0\7\3\5\1\7\16‘ƒ\57\49"
  .."\0\16‘ƒ\50\57\48\0K∞\14TXΩ\0\7\0@\0\1\0\7\0\7ˇ¿\56\17\55\56Y"
  .."\0K∞\12TXΩ\0\7ˇ¿\0\1\0\7\0\7\0@\56\17\55\56Y@\31\15\1\15\2\10"
  .."\3\15\4\15\5\31\1\31\2\26\3\31\4\31\5\47\1\47\2*\3\47\4\47\5"
  .."\15\93\1\3\51\23\55\51\3\2\10”å•¶å”\4Ó\1\10≤≤˛ˆ\0\1\0\27\1¯\4"
  .."Z\3j\0\3\0\25@\10\1\0\3\2\4\2\0\3\1\4\16‘ƒ\57\57\49\0\16‘‹‘Ã"
  .."\48\19'\1\23\51\24\4$\27\1¯l\1\6l\0\2\1\12\2ú\3ç\5ﬂ\0\10\0\13"
  .."\0\53≥\11\0\12\2∏\1\9≤\8\4\6∫\1\10\0\0\1\21@\11\14\12\9\11\7"
  .."W\3\5\1\9\14\16‘‘<ƒÏ\50\17\57\49\0\16ÙÙ‘<Ï\50\17\57\48\1\51\17"
  .."\51\21#\21#\53!\53\1\1!\2w¢ttä˛}\1É˛Ó\1\18\5ﬂ˝Êo∫∫y\1ì˛c\0\0"
  .."\1\1\47\5\6\3¢\5¯\0\13\0\31≤\7\0\4∏\1\3@\9\11\14\7P\8\1P\0\14"
  .."\16‘Ï‘Ï\49\0\16‘¸ƒ\50\48\1\51\22\22\51\50\54\55\51\6\6#\34&\1"
  .."\47w\12dRSa\15w\11üêêû\5¯\54\57\55\56w{z\0\0\1\2\2\5\14\2œ\5"
  System.VERA=System.VERA
  .."€\0\3\0\18∑\0ﬁ\2\4\1a\0\4\16‘Ï\49\0\16‘Ï\48\1\51\21#\2\2ÕÕ\5"
  .."€Õ\0\0\0\0\2\0\1\0\0\0\0\0\20\0\3\0\1\0\0\1\26\0\0\1\6\0\0\1"
  .."\0\0\0\0\0\0\0\1\3\0\0\0\2\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0"
  .."\0\3\4\5\6\7\8\9\10\11\12\13\14\15\16\17\18\19\20\21\22\23\24"
  .."\25\26\27\28\29\30\31 !\34#$%&'()*+,\45\46\47\48\49\50\51\52"
  .."\53\54\55\56\57:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ\91\92\93^_`"
  .."a\0bcdefghijklmnopqrstuvwxyz{|}~\127ÄÅÇÉÑÖÜáàâäãåçéèêëíìîïñó"
  .."òôöõúùûü†°¢£§•¶ß®©™´¨≠ÆØ∞±≤≥¥µ∂∑∏π∫ªºΩæø¿¡¬√ƒ≈∆«»… ÀÃÕŒœ–—\0"
  .."“”‘’÷◊ÿŸ⁄€‹›ﬁﬂ‡\0\4\2>\0\0\0:\0 \0\4\0\26\0~\0ˇ\1\7\1\17\1\31"
  .."\1\49\1B\1S\1a\1x\1~\1í\2«\2›\3©\3¿ & \48 : ¨!\34\34\6\34\30"
  .."\34+\34H\34e% ˚\2ˇˇ\0\0\0 \0†\1\6\1\12\1\30\1\48\1A\1R\1^\1x"
  .."\1}\1í\2∆\2ÿ\3©\3¿ \19 \48 \57 ¨!\34\34\2\34\15\34+\34H\34`%"
  .." ˚\1ˇˇˇ„\0\0ˇı\0\0ˇÿ\0\0ˇ†ˇ^\0\0ˇCˇhˇ\20\0\0\0\0¸ˆ¸€\0\0‡ñ‡Ö"
  .."‡Vﬂj\0\0\0\0ﬁqﬁ_\0\0⁄Ô\5ø\0\1\0\0\0\56\0\0\0Ù\0\0\0¸\0\0\0\0"
  .."\0˙\0\0\0\0\0\0\0˙\0¸\0\0\0\0\1\2\0\0\0\0\0\0\0\0\1 \1(\0\0\0"
  .."\0\1B\0\0\0\0\0\0\0¨\0£\0Ñ\0Ö\0Ω\0ñ\0Á\0Ü\0é\0ã\0ù\0©\0§\1\0"
  .."\0ä\0Ÿ\0É\0ì\0Ò\0Ú\0ç\0ó\0à\0√\0›\0\0û\0™\0Û\0Ù\0ı\0¢\0≠\0…"
  .."\0«\0Æ\0b\0c\0ê\0d\0À\0e\0»\0 \0œ\0Ã\0Õ\0Œ\0Ë\0f\0“\0–\0—\0Ø"
  .."\0g\0Ô\0ë\0’\0”\0‘\0h\0Í\0Ï\0â\0j\0i\0k\0m\0l\0n\0†\0o\0q\0p"
  .."\0r\0s\0u\0t\0v\0w\0È\0x\0z\0y\0{\0}\0|\0∏\0°\0\127\0~\0Ä\0Å"
  .."\0Î\0Ì\0∫\0˝\0˛\0\0\0\0\0\0\0ˇ\0¯\0÷\0˘\0˙\0„\0‰\0◊\0‡\0⁄\0€"
  .."\0‹\0ﬂ\0ÿ\0ﬁ\0≤\0≥\0\0\0\0\0\0\0∂\0∑\0ƒ\0\0\0¥\0µ\0≈\0\0\0Ç\0"
  .."¬\0á\0\0\0\0\0\0\0´\0ò\0\0\0\0\0\0\0®\0ö\0\0\0ô\0Ó\0\0\0\0\0"
  .."º\0\0\0\0\0\0\1\1\0•\0\0\0\0\0\0\0í\0è\0\0\0\0\0\0\0î\0ï\4—\0"
  .."h\0\0\0\0\4—\0\0\4—\0\0\4—\2\4\4—\1R\4—\0\2\4—\0æ\4—\0!\4—\0"
  .."\57\4—\2\16\4—\1™\4—\1\92\4—\0¶\4—\0X\4—\1ì\4—\1d\4—\1È\4—\0"
  .."f\4—\0Ö\4—\0ˆ\4—\0ò\4—\0â\4—\0f\4—\0è\4—\0Ö\4—\0ã\4—\0É\4—\0"
  .."\127\4—\1È\4—\1ì\4—\0X\4—\0X\4—\0X\4—\0Ù\4—\0\27\4—\0%\4—\0¶"
  .."\4—\0ã\4—\0â\4—\0≈\4—\0È\4—\0f\4—\0â\4—\0…\4—\0m\4—\0â\4—\0◊"
  .."\4—\0V\4—\0ã\4—\0u\4—\0≈\4—\0u\4—\0è\4—\0ã\4—\0\47\4—\0ì\4—\0"
  .."\57\4—\0\0\4—\0\18\4—\0%\4—\0ú\4—\1œ\4—\0f\4—\1Z\4—\0H\4—\0\0"
  .."\4—\1\23\4—\0Ö\4—\0¡\4—\0√\4—\0{\4—\0{\4—\0√\4—\0{\4—\0√\4—\0"
  System.VERA=System.VERA
  .."≤\4—\0∫\4—\0Ï\4—\0†\4—\0m\4—\0√\4—\0â\4—\0æ\4—\0â\4—\1j\4—\0"
  .."’\4—\0É\4—\0√\4—\0d\4—\0\0\4—\0L\4—\0h\4—\0À\4—\0›\4—\2\18\4"
  .."—\0›\4—\0X\4—\0%\4—\0%\4—\0ã\4—\0≈\4—\0ã\4—\0u\4—\0ì\4—\0Ö\4"
  .."—\0Ö\4—\0Ö\4—\0Ö\4—\0Ö\4—\0Ö\4—\0√\4—\0{\4—\0{\4—\0{\4—\0{\4"
  .."—\0≤\4—\0≤\4—\0≤\4—\0≤\4—\0√\4—\0â\4—\0â\4—\0â\4—\0â\4—\0â\4"
  .."—\0√\4—\0√\4—\0√\4—\0√\4—\0¢\4—\1+\4—\0’\4—\0ã\4—\0«\4—\1?\4"
  .."—\0j\4—\0º\4—\0\0\4—\0\0\4—\0\0\4—\1€\4—\1?\4—\0X\4—\0\0\4—\0"
  .."\8\4—\0)\4—\0X\4—\0V\4—\0X\4—\0%\4—\0√\4—\0æ\4—\0è\4—\0ò\4—\0"
  .."P\4—\0Å\4—\1\14\4—\0Ù\4—\0J\4—\0)\4—\0\47\4—\0¡\4—\2\4\4—\0X"
  .."\4—\0;\4—\0\0\4—\0X\4—ˇ˙\4—\0w\4—\0¡\4—\0P\4—\0\0\4—\0%\4—\0"
  .."%\4—\0u\4—\0H\4—\0\14\4—\0\0\4—\0\0\4—\0”\4—\0”\4—\1œ\4—\1œ\4"
  .."—\0X\4—\0u\4—\0h\4—\0%\4—\0f\4—\0Õ\4—\1Z\4—\1§\4—\0#\4—\0#\4"
  .."—\0¢\4—\1È\4—\1ì\4—\0”\4—\0\0\4—\0%\4—\0≈\4—\0%\4—\0≈\4—\0≈\4"
  .."—\0…\4—\0…\4—\0…\4—\0…\4—\0u\4—\0u\4—\0u\4—\0ì\4—\0ì\4—\0ì\4"
  .."—\0≤\4—\1)\4—\1\31\4—\1=\4—\1\47\4—\2\2\4—\1V\4—\1ã\4—\1X\4—"
  .."\1§\4—\1)\4—ˇˆ\4—\0L\4—\0ã\4—\0’\4—\0ú\4—\0À\4—\2\18\4—\0\8\4"
  .."—\0â\4—\0%\4—\0h\4—\0…\4—\0æ\4—\0X\4—\0ñ\4—\1X\4—\1B\4—\1F\4"
  .."—\0\27\4—\0\27\4—\0\27\4—\0f\4—\0{\4—\0…\4—\0ã\4—\0’\4—\0ã\4"
  .."—\0√\4—\0ã\4—\0√\4—\0{\4—\1d\4—\1È\4—\0%\4—\1?\4—\1€\4—\1\31"
  .."\4—\1y\4—\1\55\4—\1\55\4—\0\27\4—\1\12\4—\1\47\4—\2\2\0\2\0\0"
  .."\0\0\0\0ˇ+\0ç\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\13\0"
  .."\0\0\1\0\2\0\3\0\4\0\5\0\6\0\7\0\8\0\9\0\10\0\11\0\12\0\13\0"
  .."\14\0\15\0\16\0\17\0\18\0\19\0\20\0\21\0\22\0\23\0\24\0\25\0"
  .."\26\0\27\0\28\0\29\0\30\0\31\0 \0!\0\34\0#\0$\0%\0&\0'\0(\0)"
  .."\0*\0+\0,\0\45\0\46\0\47\0\48\0\49\0\50\0\51\0\52\0\53\0\54\0"
  .."\55\0\56\0\57\0:\0;\0<\0=\0>\0?\0@\0A\0B\0C\0D\0E\0F\0G\0H\0"
  .."I\0J\0K\0L\0M\0N\0O\0P\0Q\0R\0S\0T\0U\0V\0W\0X\0Y\0Z\0\91\0\92"
  .."\0\93\0^\0_\0`\0a\0b\0c\0d\0e\0f\0g\0h\0i\0j\0k\0l\0m\0n\0o\0"
  .."p\0q\0r\0s\0t\0u\0v\0w\0x\0y\0z\0{\0|\0}\0~\0\127\0Ä\0Å\0Ç\0"
  .."É\0Ñ\0Ö\0Ü\0á\0à\0â\0ä\0ã\0å\0ç\0é\0è\0ê\0ë\0í\0ì\0î\0ï\0ñ\0"
  .."ó\0ò\0ô\0ö\0õ\0ú\0ù\0û\0ü\0†\0°\0¢\0£\0§\0•\0¶\0ß\0®\0©\0™\0"
  .."´\0¨\0≠\0Æ\0Ø\0∞\0±\0≤\0≥\0¥\0µ\0∂\0∑\0∏\0π\0∫\0ª\0º\0Ω\0æ\0"
  System.VERA=System.VERA
  .."ø\0¿\0¡\0¬\0√\0ƒ\0≈\0∆\0«\0»\0…\0 \0À\0Ã\0Õ\0Œ\0œ\0–\0—\0”\0"
  .."‘\0’\0÷\0◊\0ÿ\0Ÿ\0⁄\0€\0‹\0›\0ﬁ\0ﬂ\0‡\0·\0‚\0„\0‰\0Â\0Ê\0Á\0"
  .."Ë\0È\0Í\0Î\0Ï\0Ì\0Ó\0Ô\0\0Ò\0Ú\0Û\0ı\0Ù\0ˆ\0¯\0˘\0˙\0˚\0¸\0"
  .."˝\0˛\0ˇ\1\0\1\1\1\2\1\3\1\4\1\5\1\6\1\7\1\8\1\9\1\10\1\11\1\12"
  .."\1\13\1\14\9sfthyphen\14periodcentered\4Euro\5c\54\52\53\57\5"
  .."c\54\52\54\48\5c\54\52\54\49\5c\54\52\54\56\5c\54\52\55\48\5"
  .."c\54\52\55\50\5c\54\52\55\55\5c\54\52\55\56\5c\54\52\55\53\5"
  .."c\54\52\55\54\0\0\0\0\0%\0%\0%\0%\0K\0m\0À\1J\1Õ\2z\2ë\2Ω\2È"
  .."\3\54\3b\3\127\3ï\3™\3ƒ\4á\4≤\5\10\5i\5ß\5ı\6P\6~\6Á\7A\7b\7"
  .."å\7≤\7”\7˜\8j\8Ù\9\92\9∞\9ı\10\46\10\91\10Ç\10”\10˛\11)\11^\11"
  .."≈\11·\12A\12è\12Œ\13\7\13\91\13¡\14?\14`\14ß\14·\15m\15Ô\16\50"
  .."\16l\16ç\16©\16 \16Ï\17\1\17)\17û\17Ê\18*\18r\18∆\19\1\19d\19"
  .."ú\19–\20\11\20â\20µ\21O\21Ü\21¬\22\11\22T\22õ\23\16\23J\23Å\23"
  .."«\24l\24·\25V\25ô\25˛\26\21\26|\26º\26…\27c\27p\27}\27ä\27ó\27"
  .."§\27±\27æ\27À\27ÿ\27Â\27Ú\27ˇ\28\12\28\25\28&\28\51\28@\28M\28"
  .."Z\28g\28t\28Å\28é\28õ\28®\28µ\28¬\28œ\28‹\28È\29\21\29P\29≤\29"
  .."˚\30å\30¨\30Ÿ\31J\31˛ ã Â!\12!M!è!Í\34l\34Œ#\4#\51#a#À$#$Ä$∑"
  .."$⁄% %u%Ê&\45&Ä'('©(#(J(f(ó)\21)é)À*\5*A*m*m*z*á*î*‡+k+Ä+î+¡+"
  .."Ô,\12,),V,Ä,ç,ö,¥\45?\45`\45É\45“\46\22\46W\46o\46ç\46Ω\47e\47"
  .."r\47\127\47å\47ô\47¶\47≥\47¿\47Õ\47⁄\47Á\47Ù\48\1\48\14\48\27"
  .."\48(\48O\48|\49\7\49\29\49S\49{\49Õ\50\1\50C\50t\50¢\50€\51\34"
  .."\51\47\51<\51I\51V\51{\51…\52S\52`\52m\52≠\52ˆ\53\12\53E\53x"
  .."\53—\54\57\54J\54\91\54l\54y\54Ü\54ì\54†\54≠\54∫\54«\54‘\54·"
  .."\55>\55T\55l\55Ù\56\47\56r\57\8\57K\57ã\57“\57Ì:$:N:d\0\1\0\0"
  .."\1\13\0M\0\7\0F\0\4\0\2\0\16\0@\0\7\0\0\5W\7\27\0\3\0\1\0\1\0"
  .."\0\7m˛\29\0\0\4—ˇˆˇ¯\4Ÿ\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\13"
  .."\0\1\4—\1ê\0\5\0\4\5G\4Ã\0\0˛B\5G\4Ã\0\0\2S\0ç\2f\8\2\2\11\6"
  .."\9\3\8\4\2\2\4Ä\0\0Ø\16\0 J\0\0\0\0\0\0\0\0Bits\0@\0 ˚\2\6\20"
  .."˛\20\1ö\7m\1„\0\0\0\1\0\0\0\0\0\0\0\1\0\0B\0\29π\4—\4`\0\0#c"
  .."\5’\0\0VeraSansMono\0\0\0\0ˇˇˇˇ\54ˇˇ˛\54\50\56R\48\48\0\0@\0"
  .."\0\0\0\0\0\20\0\0\1\16\9\5\5\0\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  System.VERA=System.VERA
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5"
  .."\5\5\5\5\5\5\5\5\5\5\5\5\0\10\6\6\0\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6\6"
  .."\6\6\6\6\6\6\6\6\6\6\6\6\6\6\0\11\7\7\0\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\0\12\7\7\0\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  System.VERA=System.VERA
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7"
  .."\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\7\0\13\8\8\0\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\0\14\8\8\0\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8"
  .."\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\8\0\15\9\9\0\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9"
  .."\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\9\0\16\10\10\0"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  System.VERA=System.VERA
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\0\17\10\10\0\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10"
  .."\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\10\0\18\11"
  .."\11\0\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  System.VERA=System.VERA
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\0\19\11\11\0\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11"
  .."\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\11\0\20"
  .."\12\12\0\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  System.VERA=System.VERA
  .."\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12\12"
  .."\12\12\12\12\12\12\12\12\12\0\21\13\13\0\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\0\22\13\13\0\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13\13"
  .."\13\13\13\13\13\13\13\13\13\13\13\0\23\14\14\0\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  System.VERA=System.VERA
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\0\24\14\14\0\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14\14"
  .."\14\14\14\14\14\14\14\14\14\14\14\14\14\0\25\15\15\0\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  System.VERA=System.VERA
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15\15"
  .."\15\15\15\15\0\26\16\16\0\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\0\27\16\16\0\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  .."\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16\16"
  System.VERA=System.VERA
  .."\16\16\16\16\16\16\0\28\17\17\0\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17"
  .."\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\17\0\0\0\0\2"
  .."\0\8\0\2ˇˇ\0\3\0\1\0\0\0\2\0\0‰•âÎ_\15<ı\0\31\8\0\0\0\0\0∫¿Ó"
  .."õ\0\0\0\0∫¬l\5ˇˆ˛\29\4Ÿ\7m\0\0\0\8\0\1\0\0\0\0\0\000"
  System.VERA=string.format("%s",System.VERA)

  System.Fntbuf = pge.texture.create(64,64)

  function System.VeraInit()
  --This function is needed because Font load from memory 
  --isn't working (?).
    System.fpath = System.EbPath..System.FDV..System.TTFONT
    if pge.file.exists(System.fpath) then
      System.Font1 = pge.font.load(System.fpath,System.FBHGT,PGE_RAM)
    else
      --write out System.VERA to file if not found
      fontfile = io.open(System.fpath,"w+")
      fontfile:setvbuf("full")
      fontfile:write(System.VERA)
      fontfile:flush()
      fontfile:close()
      System.Font1 = pge.font.load(System.fpath,System.FBHGT,PGE_RAM)
      pge.file.remove(System.fpath)
    end
  end
  System.VeraInit()

  --System Font relative character dimensions
  System.fwids =
  {
    0,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,
    20,20,20,20,20,20,20,20,20,20,20,10,13,15,26,21,31,25,9,13,13,
    16,26,10,12,9,11,20,20,20,21,20,20,20,21,20,20,11,11,26,26,26,
    17,32,22,21,23,24,20,18,25,24,9,9,21,18,27,24,25,19,25,22,20,
    20,24,22,32,22,19,21,13,11,13,27,17,16,20,21,18,21,20,11,21,21,
    9,9,19,9,31,21,20,21,21,13,17,13,21,19,26,19,19,16,21,11,21,26,
    20,
  }

  Font =
  {
       --methods
       createProportional,
       createMonoSpaced,
       load,
   
       --properties
       PGEFont,       -- PGE Font
       ftyp,          -- Font type identifier
       wpx,hpx,       -- pixel size
  }
  
  --methods

  Font.createProportional = function()
    local fnt = {} ; setmetatable(fnt,{__index=Font})
    fnt.ftyp = System.FPROPR
    fnt.PGEFont = System.Font1
    fnt.wpx,fnt.hpx = System.FPWDF,System.FPHDF
    return fnt
  end

  Font.createMonoSpaced = function()
    local fnt = {} ; setmetatable(fnt,{__index=Font})
    fnt.ftyp = System.FMSPAC
    fnt.PGEFont = System.Font1
    fnt.wpx,fnt.hpx = System.FPWDF,System.FPHDF
    return fnt
  end

  Font.load = function(filepath)
    local fnt = {} ; setmetatable(fnt,{__index=Font})
    fnt.ftyp = System.F_LOAD
    if pge.file.exists(filepath) then
      fnt.PGEFont = pge.font.load(filepath,System.FBHGT)
    end
    if not fnt.PGEFont then fnt.PGEFont = System.Font1 end
    fnt.wpx,fnt.hpx = System.FPWDF,System.FPHDF
    return fnt
  end

  --metamethods

  function Font:setPixelSizes(fpx,fpy)
    local fnt = self
    if type(fpx)~=System.NUMBER then fpx = fnt.wpx end
    if type(fpy)~=System.NUMBER then fpy = fnt.hpx end
    fpx = math.max(fpx,0) ; fpx = math.min(fpx,System.FWDMX)
    fpy = math.max(fpy,1) ; fpy = math.min(fpy,System.FHGMX)

    if fpx==0 then
      fpx = math.ceil(fpy*0.75)  --fpx proportional to fpy
    end

    self.wpx,self.hpx = fpx,fpy
  end

  function Font:setCharSize(width,height,dpiX,dpiY)
    self:setPixelSizes(width,height)
  end

  function Font:getTextSize(str)
  --Returns the width and height, which will be used, if the
  --specified text is drawn with this font and the current 
  --font size.
    local fnt = self
    local txtwd,txthg = 0,0
    if type(str)==System.STRING and str~=System.NEWSTR then
      Image.wdf = fnt.wpx/30
      for ch = 1,string.len(str) do
        Image.ci = string.sub(str,ch,ch)
        if fnt.ftyp~=System.FPROPR then
          Image.ciwd = fnt.PGEFont:measure(Image.ci)
        else
          Image.ciwd = System.fwids[string.byte(Image.ci)+1]*System.FWDFC0
        end
        Image.chwid = math.floor(Image.ciwd*Image.wdf)
        txtwd = txtwd+Image.chwid
      end
      txthg = math.floor(fnt.hpx*System.FHGFAC)
    end
    return {width=txtwd,height=txthg}
  end


--GRAPHICS--

  Image =
  {
     --methods
     createEmpty,
     load,
  
     --properties
     PGETexture,      --texture
     wd,hg,           --dimensions
  }
  
  --8x8 transparent black PNG in RAM
  Image.apng8 = "\137PNG\13\10\26\10\0\0\0\13IHDR\0\0\0\8"..
                "\0\0\0\8\8\6\0\0\0\196\15\190\139\0\0\0\15"..
                "IDAT\24\149c\96\24\5\12\12\12\12\0\1\8\0\1"..
                "\125A\165\206\0\0\0\0IEND\174B\96\130"
  
  --32x32 transparent black PNG file in RAM
  Image.apng32 = "\137PNG\13\10\26\10\0\0\0\13IHDR\0\0\0\32\0\0\0"..
                 "\32\8\6\0\0\0szz\244\0\0\0\26IDATX\133\237\193\1"..
                 "\1\0\0\0\130\32\255\175nH\64\1\0\0\0\239\6\16\32"..
                 "\0\1G\1\160\136\0\0\0\0IEND\174B\96\130"
  
  
  Image.createEmpty = function(width,height)
  --Creates and returns an empty image, initially cleared.
  --Max. width and height is 512.
    
    local img = {} ; setmetatable(img,{__index=Image})
    collectgarbage("stop")
    img.PGETexture = pge.texture.create(width,height)
    if not img.PGETexture then
      error("texture creation error")
    end
    img.wd,img.hg = width,height
    collectgarbage("step") ; collectgarbage("restart")
    return img
  end
  
  Image.load = function(filename)
  -- Loads an image. Returns an Image object.
  -- Currently only PNG files are supported.
    local img = {} ; setmetatable(img,{__index=Image})
    System.pgegfx()
    collectgarbage("stop")
    local imld = pge.texture.load(filename)
    if not imld then error("PNG load error") end
    img.wd,img.hg = imld:width(),imld:height()
    pge.gfx.startdrawing()
    img.PGETexture = pge.texture.create(img.wd,img.hg,PGE_PIXEL_FORMAT_8888,PGE_VRAM)
    collectgarbage("collect")
    if not img.PGETexture then
      pge.delay(10000)
      img.PGETexture = pge.texture.create(img.wd,img.hg,PGE_PIXEL_FORMAT_8888,PGE_VRAM)
      if not img.PGETexture then
        pge.delay(10000)
        img.PGETexture = pge.texture.create(img.wd,img.hg)
        if not img.PGETexture then
          error("Image.load: Couldn't create new image in VRRAM")
        end
        img.PGETexture:tovram()
      end
    end
    img.PGETexture:settarget()
    imld:activate()
    pge.delay(5000)
    imld:draweasy(0,0)
    pge.delay(5000)        --(toram() fails without this delay (?))
    img.PGETexture:toram()
    pge.gfx.enddrawing()

    pge.gfx.startdrawing()
    imld = nil
    collectgarbage("step") ; collectgarbage("restart")
    return img
  end
  
  System.pgegfx = function()
  --enable the PGE API
    if System.quickImage then
      collectgarbage("stop")
      --move current enabled image to RAM
      if not pge.texture.toram(System.quickImage) then
        pge.delay(5000)
        if not pge.texture.toram(System.quickImage) then

-- comment out this error (?) 
--          error("texture RRAM move error")
--  
        end
      end
      System.quickImage = nil
      collectgarbage("collect"); collectgarbage("restart")
      pge.delay(5000)
    end
  end
  System.pgegfx()
  
  --metamethods
  
  function Image:gfxenable()
  --enable PGE graphics to an Image by moving it to VRAM
  --if not already there
  
    local img = self.PGETexture
    if System.quickImage==nil or img~=System.quickImage then
      System.pgegfx()
      --move image to VRAM
      System.quickImage = img
      pge.delay(7000)
      if not pge.texture.tovram(img) then
        pge.delay(7000)
        if not img:tovram() then
          error("texture VRRAM move error")
        end
      end
      collectgarbage("step"); collectgarbage("restart")
      pge.delay(7000)
      return 
    end
  end
  
  function Image:save(filename)
  --Saves an image to memory stick.
  --PNG files only are supported.
    local img = self.PGETexture
    collectgarbage("stop")
    img:activate()
    img:save(filename)
    collectgarbage("step"); collectgarbage("restart")
  end
  
  function Image:width()
  --Returns the width of an image.
    return self.wd
  end     
  
  function Image:height()
  --Returns the height of an image.
    return self.hg
  end
  
  Image.frec = pge.texture.create(8,8) --fill colour texture
  Image.frec:tovram()
 
  function Image:clear(color)
  --clear Image to color
    if type(color)==Image.TCTYPE then color = color.PGEColor
                                 else color = System.FBCOL
    end
    local img = self.PGETexture

    pge.gfx.startdrawing()
    Image.frec:settarget()
    pge.gfx.clearscreen(color)
    Image.frec:activate()
    self:gfxenable() ; img:settarget() 
    Image.frec:draw(0,0,img:width(),img:height(),0,0,3,3,0,255)

    pge.gfx.enddrawing()
  end
  

  function System.fontPrint(fnt,x,y,str,colr,bcolr,img)

    if type(str)~=System.STRING or str=="" then return end
    if type(colr)~=Image.TCTYPE then return end
    if type(bcolr)==Image.TCTYPE then bcolr = bcolr.PGEColor
                                 else bcolr = System.FBCOL
    end
    collectgarbage("stop")
    if img then img:tovram() ; collectgarbage("step") end
    
    fnt.wpx = fnt.wpx or System.FPWDF
    fnt.hpx = fnt.wpx or System.FPHDF
    Image.wdf = fnt.wpx/30
    System.Fntbuf:tovram()  
    for ch = 1,string.len(str) do
      pge.gfx.startdrawing()
      Image.ci = string.sub(str,ch,ch)
      if fnt.ftyp~=System.FPROPR then
        Image.ciwd = fnt.PGEFont:measure(Image.ci)
      else
        Image.ciwd = System.fwids[string.byte(Image.ci)+1]*System.FWDFC0
      end
      Image.chwid = math.floor(Image.ciwd*Image.wdf)
      Image.chhgt = math.floor(fnt.hpx*System.FHGFAC)

      pge.font.activate(fnt.PGEFont)
      System.Fntbuf:settarget()
      pge.gfx.clearscreen(bcolr)
      fnt.PGEFont:print(0,0,colr.PGEColor,Image.ci)
      System.Fntbuf:activate()
      if img then img:settarget()
             else pge.gfx.rendertoscreen()
      end
      System.Fntbuf:draw(x,y,Image.chwid,Image.chhgt,0,0,Image.ciwd+System.FCHSPC,System.FBHGT)
      x = x+Image.chwid
      pge.gfx.enddrawing()
    end
    System.Fntbuf:toram()

    if img then img:toram() end
    collectgarbage("step") ; collectgarbage("restart")
  end  
  
  function Image:fontPrint(fnt,x,y,str,colr,bcolr)
    System.fontPrint(fnt,x,y,str,colr,bcolr,self.PGETexture)
  end

  function Image:pixel(x,y,colr)
  --set/get the color of a pixel.
    local img = self.PGETexture
    local clr
  
    pge.gfx.startdrawing()
    self:gfxenable(true) ; img:settarget() 
    if not colr then
      local pcol = pge.texture.pixel(img,x,y)
      clr = {} ; setmetatable(clr,{__index=Color})
      clr.PGEColor = pcol
      clr.ctab =
      {
         r = pge.gfx.red(pcol),
         g = pge.gfx.green(pcol),
         b = pge.gfx.blue(pcol),
         a = pge.gfx.alpha(pcol),
      }
    else
      pge.texture.pixel(img,x,y,colr.PGEColor)
    end
    pge.gfx.enddrawing()
    return clr
  end
  
  function Image:fillRect(x,y,width,height,color)
  --Draws a filled rectangle.
    if type(color)==Image.TCTYPE then color = color.PGEColor
                                 else color = System.FBCOL
    end
    local img = self.PGETexture
    pge.gfx.startdrawing()
  
    Image.frec:settarget()
    pge.gfx.clearscreen(color)
    Image.frec:activate()
  
    self:gfxenable() ; img:settarget() 
    Image.frec:draw(x,y,width+1,height+1,0,0,3,3,0,255)
    pge.gfx.enddrawing()
  end
  
  function Image:drawLine(x0,y0,x1,y1,color)
  --Draws a line.
    if type(color)==Image.TCTYPE then color = color.PGEColor
                                 else color = System.FBCOL
    end
    local img = self.PGETexture
    pge.gfx.startdrawing()
    self:gfxenable() ; img:settarget() 
    if x0==x1 and y0==y1 then
      pge.gfx.drawrect(x0,y0,1,1,color)
    else
      pge.gfx.drawline(x0,y0,x1,y1,color)
    end
    pge.gfx.enddrawing()
  end
  
  function Image:blit(x,y,imgS,srcx,srcy,width,height,alpha)
  --Blit Image imgS to image at pixel coordinate (x,y).
  --(srcx,srcy) is the position in the source image, from
  --where a rectangle of size (width,height) is copied.
  --defaults: (0,0),(imgS:width(),imgS:height())
  --(alpha) is a bool flag to enable/disable transparency,default:true
    local img = self.PGETexture
    local simg = imgS.PGETexture
    System.argc = select("#",x,y,imgS,srcx,srcy,width,height,alpha)
    if System.argc<=4 then
      if System.argc==4 then alpha = srcx end
      srcx,srcy = 0,0
      width,height = simg:width(),simg:height()
    end
  
    if not srcx or type(srcx)~=System.NUMBER then srcx = 0 end
    if not srcy or type(srcy)~=System.NUMBER then srcy = 0 end
    if not width or type(width)~=System.NUMBER then
      width = simg:width()
    end
    if not height or type(height)~=System.NUMBER then
      height = simg:height()
    end
    pge.gfx.startdrawing()
    self:gfxenable() ; img:settarget() 
    collectgarbage("stop")
    if img==simg then

  --blit to self  --this code's not working (?)
      System.pgegfx()
      System.newImg = pge.texture.create(simg:width(),simg:height(),PGE_PIXEL_FORMAT_8888,PGE_VRAM)
      System.newImg:settarget()
      simg:activate()
      simg:draweasy(0,0)
      simg:draw(x,y,width,height,srcx,srcy,srcx+width,srcy+height,0,255)
      imgS.PGETexture = System.newImg
      self.PGETexture = System.newImg
      pge.delay(5000)
      System.newImg:toram()
  --

    else
      self:gfxenable() ; img:settarget() 
      simg:activate()
      simg:draw(x,y,width,height,srcx,srcy,srcx+width,srcy+height,0,255)
    end
    pge.gfx.enddrawing()
    collectgarbage("step") ; collectgarbage("restart")
  end
  
  --character map for System.print
  Image.chmap =
  {    --map--                             --ascii--
     "\0\0\0\0\0\0\0\0",                    -- 0
     "\60\66\165\129\165\153\66\60",        -- 1
     "\60\126\219\255\255\219\102\60",      -- 2
     "\108\254\254\254\124\56\16\0",        -- 3
     "\16\56\124\254\124\56\16\0",          -- 4
     "\16\56\84\254\84\16\56\0",            -- 5
     "\16\56\124\254\254\16\56\0",          -- 6
     "\0\0\0\48\48\0\0\0",                  -- 7
     "\255\255\255\231\231\255\255\255",    -- 8
     "\56\68\130\130\130\68\56\0",          -- 9
     "\199\187\125\125\125\187\199\255",    -- 10
     "\15\3\5\121\136\136\136\112",         -- 11
     "\56\68\68\68\56\16\124\16",           -- 12
     "\48\40\36\36\40\32\224\192",          -- 13
     "\60\36\60\36\36\228\220\24",          -- 14
     "\16\84\56\238\56\84\16\0",            -- 15
     "\16\16\16\124\16\16\16\16",           -- 16
     "\16\16\16\255\0\0\0\0",               -- 17
     "\0\0\0\255\16\16\16\16",              -- 18
     "\16\16\16\240\16\16\16\16",           -- 19
     "\16\16\16\31\16\16\16\16",            -- 20
     "\16\16\16\255\16\16\16\16",           -- 21
     "\16\16\16\16\16\16\16\16",            -- 22
     "\0\0\0\255\0\0\0\0",                  -- 23
     "\0\0\0\31\16\16\16\16",               -- 24
     "\0\0\0\240\16\16\16\16",              -- 25
     "\16\16\16\31\0\0\0\0",                -- 26
     "\16\16\16\240\0\0\0\0",               -- 27
     "\129\66\36\24\24\36\66\129",          -- 28
     "\1\2\4\8\16\32\64\128",               -- 29
     "\128\64\32\16\8\4\2\1",               -- 30
     "\0\16\16\255\16\16\0\0",              -- 31
     "\0\0\0\0\0\0\0\0",                    -- 32
     "\32\32\32\32\0\0\32\0",               -- 33
     "\80\80\80\0\0\0\0\0",                 -- 34
     "\80\80\248\80\248\80\80\0",           -- 35
     "\32\120\160\112\40\240\32\0",         -- 36
     "\192\200\16\32\64\152\24\0",          -- 37
     "\64\160\64\168\144\152\96\0",         -- 38
     "\16\32\64\0\0\0\0\0",                 -- 39
     "\16\32\64\64\64\32\16\0",             -- 40
     "\64\32\16\16\16\32\64\0",             -- 41
     "\32\168\112\32\112\168\32\0",         -- 42
     "\0\32\32\248\32\32\0\0",              -- 43
     "\0\0\0\0\0\32\32\64",                 -- 44
     "\0\0\0\120\0\0\0\0",                  -- 45
     "\0\0\0\0\0\96\96\0",                  -- 46
     "\0\0\8\16\32\64\128\0",               -- 47
     "\112\136\152\168\200\136\112\0",      -- 48
     "\32\96\160\32\32\32\248\0",           -- 49
     "\112\136\8\16\96\128\248\0",          -- 50
     "\112\136\8\48\8\136\112\0",           -- 51
     "\16\48\80\144\248\16\16\0",           -- 52
     "\248\128\224\16\8\16\224\0",          -- 53
     "\48\64\128\240\136\136\112\0",        -- 54
     "\248\136\16\32\32\32\32\0",           -- 55
     "\112\136\136\112\136\136\112\0",      -- 56
     "\112\136\136\120\8\16\96\0",          -- 57
     "\0\0\32\0\0\32\0\0",                  -- 58
     "\0\0\32\0\0\32\32\64",                -- 59
     "\24\48\96\192\96\48\24\0",            -- 60
     "\0\0\248\0\248\0\0\0",                -- 61
     "\192\96\48\24\48\96\192\0",           -- 62
     "\112\136\8\16\32\0\32\0",             -- 63
     "\112\136\8\104\168\168\112\0",        -- 64
     "\32\80\136\136\248\136\136\0",        -- 65
     "\240\72\72\112\72\72\240\0",          -- 66
     "\48\72\128\128\128\72\48\0",          -- 67
     "\224\80\72\72\72\80\224\0",           -- 68
     "\248\128\128\240\128\128\248\0",      -- 69
     "\248\128\128\240\128\128\128\0",      -- 70
     "\112\136\128\184\136\136\112\0",      -- 71
     "\136\136\136\248\136\136\136\0",      -- 72
     "\112\32\32\32\32\32\112\0",           -- 73
     "\56\16\16\16\144\144\96\0",           -- 74
     "\136\144\160\192\160\144\136\0",      -- 75
     "\128\128\128\128\128\128\248\0",      -- 76
     "\136\216\168\168\136\136\136\0",      -- 77
     "\136\200\200\168\152\152\136\0",      -- 78
     "\112\136\136\136\136\136\112\0",      -- 79
     "\240\136\136\240\128\128\128\0",      -- 80
     "\112\136\136\136\168\144\104\0",      -- 81
     "\240\136\136\240\160\144\136\0",      -- 82
     "\112\136\128\112\8\136\112\0",        -- 83
     "\248\32\32\32\32\32\32\0",            -- 84
     "\136\136\136\136\136\136\112\0",      -- 85
     "\136\136\136\136\80\80\32\0",         -- 86
     "\136\136\136\168\168\216\136\0",      -- 87
     "\136\136\80\32\80\136\136\0",         -- 88
     "\136\136\136\112\32\32\32\0",         -- 89
     "\248\8\16\32\64\128\248\0",           -- 90
     "\112\64\64\64\64\64\112\0",           -- 91
     "\0\0\128\64\32\16\8\0",               -- 92
     "\112\16\16\16\16\16\112\0",           -- 93
     "\32\80\136\0\0\0\0\0",                -- 94
     "\0\0\0\0\0\0\248\0",                  -- 95
     "\64\32\16\0\0\0\0\0",                 -- 96
     "\0\0\112\8\120\136\120\0",            -- 97
     "\128\128\176\200\136\200\176\0",      -- 98
     "\0\0\112\136\128\136\112\0",          -- 99
     "\8\8\104\152\136\152\104\0",          -- 100
     "\0\0\112\136\248\128\112\0",          -- 101
     "\16\40\32\248\32\32\32\0",            -- 102
     "\0\0\104\152\152\104\8\112",          -- 103
     "\128\128\240\136\136\136\136\0",      -- 104
     "\32\0\96\32\32\32\112\0",             -- 105
     "\16\0\48\16\16\16\144\96",            -- 106
     "\64\64\72\80\96\80\72\0",             -- 107
     "\96\32\32\32\32\32\112\0",            -- 108
     "\0\0\208\168\168\168\168\0",          -- 109
     "\0\0\176\200\136\136\136\0",          -- 110
     "\0\0\112\136\136\136\112\0",          -- 111
     "\0\0\176\200\200\176\128\128",        -- 112
     "\0\0\104\152\152\104\8\8",            -- 113
     "\0\0\176\200\128\128\128\0",          -- 114
     "\0\0\120\128\240\8\240\0",            -- 115
     "\64\64\240\64\64\72\48\0",            -- 116
     "\0\0\144\144\144\144\104\0",          -- 117
     "\0\0\136\136\136\80\32\0",            -- 118
     "\0\0\136\168\168\168\80\0",           -- 119
     "\0\0\136\80\32\80\136\0",             -- 120
     "\0\0\136\136\152\104\8\112",          -- 121
     "\0\0\248\16\32\64\248\0",             -- 122
     "\24\32\32\64\32\32\24\0",             -- 123
     "\32\32\32\0\32\32\32\0",              -- 124
     "\192\32\32\16\32\32\192\0",           -- 125
     "\64\168\16\0\0\0\0\0",                -- 126
     "\0\0\32\80\248\0\0\0"                 -- 127
  }
  
  Image.PRWD = 8              --character width
  Image.PRHG = 8              --character height
  
  Image.PRWM1 = Image.PRWD-1  --character width-1
  Image.PRWM2 = Image.PRWD-2  --character width-2
  Image.PRHM1 = Image.PRHG-1  --character height-1
  Image.MPWD  = Image.PRWD*32 --sub-drawmap width
  
  System.BLACK = Color.new(0,0,0)
  Image.TCTYPE = type(System.BLACK)
  
  function System.print(x,y,str,colr,img)
  --print string to image or screen using the system bitmap font
    local I = Image
  
    if type(x)~=System.NUMBER or type(y)~=System.NUMBER or
       type(str)~=System.STRING or type(colr)~=I.TCTYPE then
        return
    end
    I.nstr = string.len(str)
    if I.nstr<1 then return end
  
    x,y = math.floor(x),math.floor(y)
  
    if img then
      I.dwd,I.dhg = img.PGETexture:width(),img.PGETexture:height()
    else
      I.dwd,I.dhg = System.SCRW,System.SCRH
    end
    I.pxr,I.apwd = x,I.nstr*Image.PRWD
  
    --invisibility test (clipped chars are invisible)
    if I.nstr<1 or (x+I.apwd<Image.PRWD) or (y<0) or 
       (x>=I.dwd-Image.PRWD) or (y>=I.dhg-Image.PRHG) then
      return
    end

    --print characters
    if img then
      img:gfxenable()
      img.PGETexture:settarget()
    else
      pge.gfx.rendertoscreen()
    end
    collectgarbage("stop")
    for i = 1,I.nstr do
      --move to next character position
      I.px = I.pxr ; I.pxr = I.pxr+Image.PRWD
  
      --clip to image RH edge
      if I.px>=I.dwd then break end
  
      if I.px>=0 then   --print next character
        I.chrb = string.byte(str,i,i)
        I.cstr = I.chmap[I.chrb+1]
        if I.chrb>=1 and I.chrb<=127 and I.chrb~=32 then
          --render character (Xpixel x Ypixel)
          for row = y,y+7 do
            I.col = I.px+I.PRWM1
            I.rbyt = string.byte(I.cstr,(row-y)+1)
            while I.rbyt>0 do
              I.rbd2 = math.floor(I.rbyt/2)
              if (I.rbd2+I.rbd2)~=I.rbyt then
                pge.gfx.drawrect(I.col,row,1,1,colr.PGEColor)
              end
              I.rbyt,I.col = I.rbd2,I.col-1
            end
          end
        end
      end
    end
    pge.gfx.enddrawing()
    collectgarbage("step") ; collectgarbage("restart")
  end

  

  function Image:print(x,y,str,colr)
  --print string to Image using system bitmap font
    System.print(x,y,str,colr,self)
  end


--screen object
  screen =
  {
     --properties
     vBtimer,
     vBlankTime,
     vBSyncTime,
     mSinceVB,
     mStoVB,
  }
  
  setmetatable(screen,{__index=screen})
  
  --vBlank Sync
  screen.vBtimer = pge.timer.create()
  pge.gfx.swapbuffers(true)
  screen.vBtimer:getdelta()
  pge.gfx.swapbuffers(true)
  screen.vBlankTime = screen.vBtimer:getdelta()
  
  --methods
  
  function screen.flip(vflg)
    if vflg and type(vflg)==System.BOOL then vflg = true
                                        else vflg = false
    end
    
    pge.gfx.enddrawing()
    pge.gfx.swapbuffers(vflg)
    screen.vBtimer:getdelta()
    pge.gfx.startdrawing()
  end
  
  function screen.waitVblankStart(count)
  --wait for screen Vblank
    if not count or type(count)~=System.NUMBER then count = 1 end
    screen.mSinceVB = math.fmod(screen.vBtimer:peekdelta(),screen.vBlankTime)
    screen.mStoVB = screen.vBlankTime-screen.mSinceVB
    screen.mStoVB = screen.mStoVB+((count-1)*screen.vBlankTime)
    repeat until screen.vBtimer:peekdelta()>=screen.mStoVB
  end
  
  --metamethods
  function screen:width()  return System.SCRW end     
  function screen:height() return System.SCRH end
       
  function screen:clear(color)
    if type(color)==Image.TCTYPE then color = color.PGEColor
                                 else color = System.FBCOL
    end

    pge.gfx.startdrawing()
    pge.gfx.rendertoscreen()
    pge.gfx.clearscreen(color)
    pge.gfx.enddrawing()
  end
  
  function screen:pixel(x,y,colr)
  --set/get the color of a pixel on screen.
    local clr
  
    pge.gfx.startdrawing()
    pge.gfx.rendertoscreen()
    if not colr then

      --the only way to implement this in PGE atm is by saving then
      -- reading back a screenshot - completely impractical.
      --Using a 480x272 texture as a screen buffer could work,
      -- but obviously involves a heavy speed cost.

      --default return RED--
      local clr = {} ; setmetatable(clr,{__index=Color})
      --default return RED--
      clr.ctab = {r=255,g=0,b=0,a=255}                                            
      clr.PGEColor = System.SPXDF
      return clr
    else
      pge.gfx.drawrect(x,y,1,1,colr.PGEColor)
    end
    pge.gfx.enddrawing()
  end
  
  function screen:fillRect(x,y,width,height,color)
    pge.gfx.startdrawing()
    pge.gfx.rendertoscreen()
    pge.gfx.drawrect(x,y,width,height,color.PGEColor)
    pge.gfx.enddrawing()
  end
  
  function screen:drawLine(x0,y0,x1,y1,color)
    pge.gfx.startdrawing()
    pge.gfx.rendertoscreen()
    if x0==x1 and y0==y1 then
      pge.gfx.drawrect(x0,y0,1,1,color.PGEColor)
    else
      pge.gfx.drawline(x0,y0,x1,y1,color.PGEColor)
    end
    pge.gfx.enddrawing()
  end
  
  function screen:blit(x,y,imgS,srcx,srcy,width,height,alpha)
    System.imb = imgS.PGETexture
    System.argc = select("#",x,y,imgS,srcx,srcy,width,height,alpha)
    if System.argc<=4 then
      if System.argc==4 then alpha = srcx end
      srcx,srcy = 0,0
      width,height = System.imb:width(),System.imb:height()
    end
  
    if not srcx or type(srcx)~=System.NUMBER then srcx = 0 end
    if not srcy or type(srcy)~=System.NUMBER then srcy = 0 end
    if not width or type(width)~=System.NUMBER then
      width = System.imb:width()
    end
    if not height or type(height)~=System.NUMBER then
      height = System.imb:height()
    end                 
    collectgarbage("stop")
    pge.gfx.startdrawing()
    pge.gfx.rendertoscreen()
    System.imb:activate()
    System.imb:draw(x,y,width,height,srcx,srcy,srcx+width,srcy+height,0,255)
    pge.gfx.enddrawing()
    collectgarbage("restart") ; collectgarbage("step")
  end
  
  function screen:print(x,y,str,colr)
  --print string to screen using system bitmap font
    System.print(x,y,str,colr)
  end

  function screen:fontPrint(fnt,x,y,str,colr,bcolr)
    System.fontPrint(fnt,x,y,str,colr,bcolr)
  end

  function screen:save(filename) pge.gfx.screenshot(filename) end


--SOUND / MUSIC
  Sound =
  {
     --methods
     load,

     --properties
     PGEwav,
  }

  Voice =
  {
     --properties
     srcSound,
  }

  --methods

  Sound.load = function(fname,lp)
    if type(fname)~=System.STRING then return end
    if type(lp)~=System.BOOL then lp = false end

    local snd = {} ; setmetatable(snd,{__index=Sound})

    snd.PGEwav = pge.wav.load(fname)
    if snd.PGEwav and lp then pge.wav.loop(snd.PGEwav,true) end
    return snd
  end

  --metamethods

  function Sound:play()
    self.PGEwav:play()
    local vc = {} ; setmetatable(vc,{__index=Voice})
    vc.srcSound = self
    return vc
  end

  function Voice:stop()
    vc.srcSound.PGEwav:stop()
  end

  function Voice:volume(v)
    vc.srcSound.PGEwav:volume(math.floor(v/255))
  end

  function Voice:pan(p)
    vc.srcSound.PGEwav:volume(255-p,p)  
  end

  function Voice:frequency(f)
    vc.srcSound.PGEwav:pitch(f)
  end

  function Voice:playing()
    vc.srcSound.PGEwav:isplaying()
  end

  Music = {}
  Music.playFile = function(file,loop)
  --Plays a music in one of the following formats:
  -- UNI, IT, XM, S3M, MOD, MTM, STM, DSM, MED, FAR, ULT or 669.
  end
  Music.pause = function() end
  Music.resume = function() end
  Music.stop = function() end
  Music.playing = function() return false end
  Music.volume = function(v) return 0 end

  SoundSystem = {}
  SoundSystem.SFXVolume = function(v) end
  SoundSystem.reverb = function(r) end
  SoundSystem.panoramicSeparation = function(pS) end

--WLAN

  Wlan = {}

  Wlan.init = function() end
  Wlan.term = function() end
  Wlan.getConnectionConfigs = function() return{} end
  Wlan.useConnectionConfig = function(number) end
  Wlan.getIPAddress = function() return System.NEWSTR end

  Socket =
  {
     --methods
     connect,
  }
  Socket.connect = function(host,port)
  --Create a new TCP/IP Socket object and start
  -- the connection process to the specified host and port.
  -- All sockets are non-blocking.
    local skt = {} ; setmetatable(skt,{__index=Socket})
    return skt
  end

  --metamethods

  function Socket:isConnected() return false end
  function Socket:createServerSocket(port)
  --Creates a server socket, which listens on the specified
  -- port for incoming connections.
    local sck = self
    local ssk = {} ; setmetatable(ssk,{__index=Socket})
    return ssk
  end
  function Socket:accept() end
  function Socket:recv() return System.NEWSTR end
  function Socket:send(string) return 0 end
  function Socket:close() end

end--System.LP2PGE()--




--[[
*******************************************************************
*******************************************************************
THIS VERSION 1.0 by dangee October '08
A dangee.net production

DISCLAIMER
 Homebrew.
 no copyright, no guarantee, totally irresponsible of all
 consequences arising as from or out of users total freedom
 to reproduce, use at own risk copy destroy debug modify
 plagiarise or abuse unreasonable or otherwise and wheresofore
 delete as appropriate

Mods/BugFixes: Add to the Changelog below to claim co-disclaimancy.

*******************************************************************

ChangeLog
---------

VERSION 1.0: 4/10/08 by dangee file name: LP2PGE.LUA


*******************************************************************
]]--
