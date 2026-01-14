	local templates = {
		leadinfx		= {},
		hilightfx		= {},
		leadoutfx		= {},
		shapefx			= {},
		translationfx	= {}
	}
	
	local utilsfx
	utilsfx = {
		guiconfig = {
			[01] = {x = 0;	y = 0;	height = 1; width = 8; class = "label";		label = "lead-in[fx]: ABC New fx"},
			[02] = {x = 10;	y = 0;	height = 1; width = 2; class = "label";		label = "         Template Type [fx]:"},
			[03] = {x = 12;	y = 0;	height = 1; width = 2; class = "dropdown";	name = "fx_type"; items = {"line", "word", "syl", "char"}; value = "syl"},
			[04] = {x = 0;	y = 1;	height = 1; width = 2; class = "label";		label = "                       Line Start Time: "},
			[05] = {x = 2;	y = 1;	height = 1; width = 6; class = "textbox";	name = "fx_start"; text = "l.start_time"},
			[06] = {x = 8;	y = 1;	height = 1; width = 2; class = "label";		label = "                 layer // Align: "},
			[07] = {x = 10;	y = 1;	height = 1; width = 2; class = "textbox";	name = "fx_layer"; text = "0"},
			[08] = {x = 12;	y = 1;	height = 1; width = 2; class = "textbox";	name = "fx_align"; text = "5"},
			[09] = {x = 0;	y = 2;	height = 1; width = 2; class = "label";		label = "                        Line End Time: "},
			[10] = {x = 2;	y = 2;	height = 1; width = 6; class = "textbox";	name = "fx_end"; text = "l.end_time"},
			[11] = {x = 8;	y = 2;	height = 1; width = 2; class = "label";		label = "                                loop: "},
			[12] = {x = 10;	y = 2;	height = 1; width = 4; class = "textbox";	name = "fx_loop"; text = "1"},
			[13] = {x = 0;	y = 3;	height = 1; width = 2; class = "label";		label = "                              Return [fx]: "},
			[14] = {x = 2;	y = 3;	height = 4; width = 4; class = "textbox";	name = "fx_return"; text = "fx.text"},
			[15] = {x = 6;	y = 3;	height = 1; width = 2; class = "label";		label = "                           Pos \"x\": "},
			[16] = {x = 8;	y = 3;	height = 1; width = 6; class = "textbox";	name = "fx_posx"; text = "fx.center"},
			[17] = {x = 6;	y = 4;	height = 1; width = 2; class = "label";		label = "                           Pos \"y\": "},
			[18] = {x = 8;	y = 4;	height = 1; width = 6; class = "textbox";	name = "fx_posy"; text = "fx.middle"},
			[19] = {x = 0;	y = 5;	height = 1; width = 2; class = "checkbox";	name = "fx_modify"; label = "Modify or Return [fx]"; value = false},
			[20] = {x = 6;	y = 5;	height = 1; width = 2; class = "label";		label = "                  Times Move: "},
			[21] = {x = 8;	y = 5;	height = 1; width = 6; class = "textbox";	name = "fx_time"; text = ""},
			[22] = {x = 0;	y = 6;	height = 1; width = 1; class = "label";		label = "keeptags [fx]:"},
			[23] = {x = 1;	y = 6;	height = 1; width = 1; class = "dropdown";	name = "fx_keept"; items = {"line", "word", "syl"}; value = ""},
			[24] = {x = 2;	y = 7;	height = 1; width = 2; class = "label";		label = "   Shape Primary Color   "},
			[25] = {x = 4;	y = 7;	height = 1; width = 2; class = "label";		label = "    Shape Border Color    "},
			[26] = {x = 6;	y = 7;	height = 1; width = 2; class = "label";		label = "   Shape Shadow Color "},
			[27] = {x = 8;	y = 7;	height = 1; width = 2; class = "label";		label = " New [fx] Name:"},
			[28] = {x = 12;	y = 7;	height = 1; width = 2; class = "label";		label = "  update: may 28th 2025"},
			[29] = {x = 2;	y = 8;	height = 2; width = 2; class = "color";		name = "fx_color1";	value = "#FFFFFF"},
			[30] = {x = 4;	y = 8;	height = 2; width = 2; class = "color";		name = "fx_color3";	value = "#B4B4B4"},
			[31] = {x = 6;	y = 8;	height = 2; width = 2; class = "color";		name = "fx_color4";	value = "#626262"},
			[32] = {x = 8;	y = 8;	height = 2; width = 6; class = "textbox";	name = "fx_namefx"; text = ""},
			[33] = {x = 0;	y = 10;	height = 1; width = 2; class = "label";		label = "New Eeffector 1.0"},
			[34] = {x = 2;	y = 10;	height = 1; width = 2; class = "intedit";	name = "fx_alpha1";	min = 0; max = 255;	value = "0"},
			[35] = {x = 4;	y = 10;	height = 1; width = 2; class = "intedit";	name = "fx_alpha3";	min = 0; max = 255;	value = "0"},
			[36] = {x = 6;	y = 10;	height = 1; width = 2; class = "intedit";	name = "fx_alpha4";	min = 0; max = 255;	value = "0"},
			[37] = {x = 8;	y = 10;	height = 1; width = 2; class = "checkbox";	name = "fx_printfx"; label = "Print Config [fx]"; value = false},
			[38] = {x = 10;	y = 10;	height = 1; width = 2; class = "label";		label = "       Template Folder [fx]:"},
			[39] = {x = 12;	y = 10;	height = 1; width = 2; class = "dropdown";	name = "fx_folder"; items = {"leadin fx", "hilight fx", "leadout fx", "shape fx", "translation fx"}; value = "leadin fx"},
			[40] = {x = 2;	y = 12;	height = 1; width = 2; class = "label";		label = " Variables [fx]:"},
			[41] = {x = 8;	y = 12;	height = 1; width = 2; class = "label";		label = " Add Tags [fx]:"},
			[42] = {x = 2;	y = 13;	height = 6; width = 6; class = "textbox";	name = "fx_variable"; text = ""},
			[43] = {x = 8;	y = 13;	height = 6; width = 6; class = "textbox";	name = "fx_addtags"; text = ""},
			[44] = {x = 0;	y = 16;	height = 1; width = 2; class = "checkbox";	name = "fx_reverse"; label = "Reverse [fx]"; value = false},
			[45] = {x = 0;	y = 17;	height = 1; width = 2; class = "checkbox";	name = "fx_noblank"; label = "Noblank [fx]"; value = true},
			[46] = {x = 0;	y = 18;	height = 1; width = 2; class = "checkbox";	name = "fx_vertical"; label = "Vertical Kanji [fx]"; value = false},
		},
		
		copy = function(array)
			local lookup = {}
			local function _copy(array)
				if type(array) ~= "table" then
					return array
				elseif lookup[array] then
					return lookup[array]
				end
				local newarray = {}
				lookup[array] = newarray
				for k, v in pairs(array) do
					newarray[_copy(k)] = _copy(v)
				end
				return setmetatable(newarray, getmetatable(array))
			end
			return _copy(array)
		end,
		
		loadfx = function(configs)
			local guifx = utilsfx.copy(utilsfx.guiconfig)
			guifx[01].label	= configs[02] --[[name fx]]
			guifx[03].value	= configs[03] --[[template type]]	guifx[05].text	= configs[04] --[[line start time]]
			guifx[10].text	= configs[05] --[[line end time]]	guifx[07].text	= configs[06] --[[layer]]
			guifx[08].text	= configs[07] --[[aling]]			guifx[12].text	= configs[08] --[[loop]]
			guifx[14].text	= configs[09] --[[return]]			guifx[16].text	= configs[10] --[[pos x]]
			guifx[18].text	= configs[11] --[[pos y]]			guifx[21].text	= configs[12] --[[time move]]
			guifx[29].value	= configs[13] --[[shape color 1]]	guifx[30].value	= configs[14] --[[shape color 3]]
			guifx[31].value	= configs[15] --[[shape color 4]]	guifx[34].value	= configs[16] --[[shape alpha 1]]
			guifx[35].value	= configs[17] --[[shape alpha 3]]	guifx[36].value	= configs[18] --[[shape alpha 4]]
			guifx[42].text	= configs[19] --[[variables]]		guifx[43].text	= configs[20] --[[add tags]]
			guifx[44].value	= configs[21] --[[reverse fx]]		guifx[45].value	= configs[22] --[[noblank]]
			guifx[46].value	= configs[23] --[[vertical kanji]]
			local mode = configs[1]
			table.insert(templates[mode], guifx)
			return guifx
		end
	}
	
	demo_leadin = utilsfx.loadfx({"leadinfx", "demo_leadin", "syl", "line.start_time", "line.end_time", "0", "5", "1", "fx.text", "fx.center", "fx.middle", "", "#FFFFFF", "#B4B4B4", "#626262", 0, 0, 0, "", "", false, true, false})
	demo_leadout = utilsfx.loadfx({"leadoutfx", "demo_leadout", "syl", "line.start_time", "line.end_time", "0", "5", "1", "fx.text", "fx.center", "fx.middle", "", "#FFFFFF", "#B4B4B4", "#626262", 0, 0, 0, "", "", false, true, false})
	demo_hilight = utilsfx.loadfx({"hilightfx", "demo_hilight", "syl", "line.start_time + syl.start_time", "line.start_time + syl.end_time", "0", "5", "1", "fx.text", "fx.center", "fx.middle", "", "#FFFFFF", "#B4B4B4", "#626262", 0, 0, 0, "", "", false, true, false})

	return templates
