*******************************************************************

 LuaPlayer/PGE script translator
 -------------------------------

 LP2PGE is a utility that can be used in PGE Lua running on
  any homebrew enabled PSP.
 Run it from a script using dofile().
 Then call System.LP2PGE().
 This allows use of a pseudo LuaPlayer 0.2 API in PGE Lua scripts. 

 It can help in adapting existing LuaPlayer scripts to PGE Lua.

  Some scripts are easser to adapt than others. Fonts and
 transparency effects do not translate well, and the GU library
 doesn't translate at all.


*******************************************************************

  Test results
  ------------

  Scripts tested so far

   LuaPlayer Apps.
   ~ LOWSER boots and runs at 100% with only minor changes
   ~ CLOCK runs well with only slight changes to the screen refresh
      sequence.
   ~ SNAKE sound worked OK after Music was disabled, and the old
      .WAV files were replaced. A pge.delay was introduced to slow
      down the main loop. A screen buffer Image was used to achieve
      transparency effects. but it leaves glitchy traces onscreen.

   Others
   ~ NOTEPAD by ema & kris, boots with only minor changes
      (eg. Chinese Fonts aren't loaded to save memory).
      The OSK works, but the predefined English fonts get
      scrambled, making screen output unintelligible.
      atm Not sure what causes this.
   ~ ROXPAINT by RoxFox64 runs well. Only a few minor adjustments
      are needed, mainly to stop multiple reloads of images
      (causes VRAM saturation for some reason). Line colour can't
      be set, because it uses color = screen:pixel(x,y)


   Every different script so far has produced different problems,
  with adjustments often needed in LP2PGE.LUA for best results.
  So using LP2PGE.LUA as an adaptable template is recommended at
  this stage.


*******************************************************************
  
  Use of LP2PGE.LUA in PGE Lua (example):
  ---------------------------------------

  --paths
  pgedir       = "ms0:/psp/game/pgelua"
  LP2PGEscript = pgedir.."/LP2PGE.LUA"

  -- Enable Luaplayer Pseudo-API
  dofile(LP2PGEscript) ; System.LP2PGE()

  savdir = System.currentDirectory(pgedir)

  black = Color.new(0,0,0)
  white = Color.new(255,255,255)
  red   = Color.new(255,0,0)

  LOGO_LP2 = Image.load("lp2Logo.png")
  LOGO_PGE = LOGO_LP2.PGETexture

  messages = 
  {
     { x=10 ,y=10 ,text = "LuaPlayer Pseudo-API 1.0.",colour=white },
     { x=20 ,y=100,text = "Push the Circle button.",colour=red },
  }

  rotate,fade,Df = 0,0,5

  repeat
    screen:clear(black)
    for index,msg in pairs(messages) do
      screen:print(msg.x,msg.y,msg.text,msg.colour)
    end
    screen:blit(240,40,LOGO_LP2)

    --The PGE Lua API can be used
    if pge and pge.running() then
      System.pgegfx()
    
      pge.gfx.startdrawing()
      pge.gfx.rendertoscreen()

      LOGO_PGE:activate()
      LOGO_PGE:draweasy(240,160,math.rad(rotate),fade)

      rotate = math.fmod(rotate+10,360)
      fade = fade+Df ; if fade>255 then fade,Df = 255,-Df end
                       if fade<63  then fade,Df =  63,-Df end
    end

    --note: screen.waitVblankStart() is replaced by a true bool 
    --      parameter in screen.flip() for accurate vsync
    screen.flip(true)

  until Controls.read():circle()
  
  System.currentDirectory(savdir)


*******************************************************************

LP2PGE.LUA 1.0 Readme by dangee Ocober 08
dan@dangee.net

links
-----
www.dangee.net
www.luaplayer.org
www.evilmana.com
www.dcemu.co.uk

*******************************************************************
