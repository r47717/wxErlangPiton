% piton game (r47717)
-module(piton).
-export([run/0, piton_run_cycle/4]).
-include_lib("wx/include/wx.hrl").

-define(FIELD_SIZE, 500).
-define(BORDER, 20).
-define(CELLS, 50).
-define(CELLSIZE, 10).

-define(ID_MENU_START, 101).
-define(ID_MENU_PAUSE, 102).
-define(ID_MENU_RESTART, 103).

-type coord() :: 0..?CELLS-1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Utils %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

random_coord() ->
	random:uniform(?CELLS) - 1.

random_item() ->
	random:uniform(10) - 1.
	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Piton structure/change functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-type piton() :: [{coord(), coord()}].
-type piton_dir() :: up | down | left | right | stopped | paused.
-type piton_grow() :: 0..100.

-spec piton_init()->piton().
piton_init() ->
	Piton = [{20, 20}, {21, 20}, {22, 20}, {23, 20}, {24, 20}].

piton_len(Piton) ->
	length(Piton) - 1.

-spec piton_move(piton(), piton_dir(), piton_grow())->piton().	
piton_move(Piton, Dir, Grow) ->
	[{X, Y}|_] = Piton,
	case Dir of
		stopped ->
			NewX = X,
			NewY = Y;
		left -> 
			NewX = if 
					X > 0 -> X - 1;
					true -> X
				   end,
			NewY = Y;
		up -> 
			NewX = X,
			NewY = if 
					Y > 0 -> Y - 1;
					true -> Y
				   end;
		right -> 
			NewX = if 
					X < ?CELLS - 1 -> X + 1;
					true -> X
				   end,
			NewY = Y;
		down -> 
			NewX = X,
			NewY = if
					Y < ?CELLS - 1 -> Y + 1;
					true -> Y
				   end
	end,
	NewDir = case (NewX == X) and (NewY == Y) or lists:member({NewX, NewY}, Piton) of
				true -> stopped;
				false -> Dir
			 end,
	if 
		NewDir /= stopped ->
			if
				Grow == true -> [{NewX, NewY}] ++ Piton;
				true -> [{NewX, NewY}] ++ lists:sublist(Piton, 1, length(Piton) - 1)
			end;
		true ->
			Piton
	end.
	
piton_run_cycle(Piton, Dir, Grow, Speed) ->
	receive
		{request_piton_state, Pid} ->
			Pid ! {piton_state, Piton},
			piton_run_cycle(Piton, Dir, Grow, Speed);
		{direction, NewDirRequested} -> 
			io:format("Requested direction: ~w~n", [NewDirRequested]),
			NewDir = calc_new_dir(Dir, NewDirRequested),
			piton_run_cycle(Piton, NewDir, Grow, Speed);
		start -> ok;
		pause -> ok;
		restart -> ok;
		stop -> ok
	after Speed ->
		%io:format("Piton: ~w~n", [Piton]),
		PitonNew = piton_move(Piton, Dir, Grow),
		fieldPid ! refresh,
		piton_run_cycle(PitonNew, Dir, Grow, Speed)
	end.

calc_new_dir(Dir, NewDirRequested) ->
	if  
		(Dir == up) and (NewDirRequested == down) -> Dir;
		(Dir == down) and (NewDirRequested == up) -> Dir;
		(Dir == left) and (NewDirRequested == right) -> Dir;
		(Dir == right) and (NewDirRequested == left) -> Dir;
		true -> NewDirRequested
	end.
	
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Items structure/change functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-type items_sym() :: 0..9.
-type items_point() :: {items_sym(), coord(), coord()}.

items_init() ->
	{X,Y,Z} = erlang:now(),
    random:seed(Y,X,Z),
	[].

-spec items_new([items_point()]) -> [items_point()].	
items_new(Items) ->
	N = random_item(),
	X = random_coord(),
	Y = random_coord(),
	pitonPid ! {request_piton_state, self()},
	receive
		{piton_state, Piton} -> ok
	end,
	case lists:member({X,Y}, Piton) or lists:any(fun({_,X1,Y1})-> (X1==X) and (Y1==Y) end, Items) of
		true -> Items;
		false -> Items ++ {N,X,Y}
	end.
	
items_remove(Items, {X,Y}) ->
	
	lists:delete(Item, Items).

items_loop(Items) ->
	receive
		start -> items_loop(Items);
		pause -> items_loop(Items);
		restart -> items_loop(Items);
		stop -> items_loop(Items)
	after 4000 ->
		NewItems = items_new(Items),
		items_loop(NewItems)
	end,
	ok.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN WINDOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


create_window(Wx) ->
	Frame = wxFrame:new(Wx, -1, "Piton Game", [{size,{?FIELD_SIZE + 2*?BORDER, ?FIELD_SIZE + 2*?BORDER}}, 
		{style, ?wxDEFAULT_FRAME_STYLE band (bnot (?wxMAXIMIZE_BOX bor ?wxRESIZE_BORDER))}]),
	wxFrame:createStatusBar(Frame,[]),
	wxFrame:setStatusText(Frame, "Piton length: ~w",[5]),
	wxFrame:setClientSize(Frame, {?FIELD_SIZE + 2*?BORDER, ?FIELD_SIZE + 2*?BORDER}),

	MenuBar = wxMenuBar:new(),
	FileMenu = wxMenu:new([]),
	HelpMenu = wxMenu:new([]),
	wxMenu:append(FileMenu, ?ID_MENU_START, "Start"),
	wxMenu:append(FileMenu, ?ID_MENU_PAUSE, "Pause"),
	wxMenu:append(FileMenu, ?ID_MENU_RESTART, "Restart"),
	wxMenu:appendSeparator(FileMenu),
	wxMenu:append(FileMenu, ?wxID_EXIT, "Exit"),
	wxMenu:append(HelpMenu, ?wxID_ABOUT, "About..."),
	wxMenuBar:append(MenuBar, FileMenu, "File"),
	wxMenuBar:append(MenuBar, HelpMenu, "Help"),
	wxFrame:setMenuBar(Frame, MenuBar),
	Frame.

about_dialog(Panel) ->
	Modal = wxMessageDialog:new(Panel, "Erlang/WxWidgets Piton game\n(c) 2015, by r47717", [{style, ?wxOK bor ?wxICON_INFORMATION}, {caption, "About Piton Application"}]),
	wxDialog:showModal(Modal),
	wxDialog:destroy(Modal).	

	
loop(Frame, Panel) ->
	receive
		#wx{ event = #wxClose{} } ->
			io:format("event: close_window~n", []),
			ok;
		#wx{ event = #wxKey{ keyCode = KeyCode} } ->
			%io:format("event: key pressed with key code ~w~n", [KeyCode]),
			case KeyCode of
				?WXK_LEFT -> pitonPid ! { direction, left }, ok;
				?WXK_RIGHT -> pitonPid ! { direction, right }, ok;
				?WXK_UP -> pitonPid ! { direction, up }, ok;
				?WXK_DOWN -> pitonPid ! { direction, down }, ok
			end,
			loop(Frame, Panel);
		#wx{id=?wxID_EXIT, event=#wxCommand{type=command_menu_selected}} ->
			wxWindow:destroy(Frame),
			ok;
		#wx{id=?wxID_ABOUT, event=#wxCommand{type=command_menu_selected}} ->
			about_dialog(Panel),
			loop(Frame, Panel);
		#wx{id=?ID_MENU_START, event=#wxCommand{type=command_menu_selected}} ->
			pitonPid ! start,
			fieldPid ! start,
			itemsPid ! start,
			loop(Frame, Panel);
		#wx{id=?ID_MENU_PAUSE, event=#wxCommand{type=command_menu_selected}} ->
			pitonPid ! pause,
			fieldPid ! pause,
			itemsPid ! pause,
			loop(Frame, Panel);
		#wx{id=?ID_MENU_RESTART, event=#wxCommand{type=command_menu_selected}} ->
			pitonPid ! restart,
			fieldPid ! restart,
			itemsPid ! restart,
			loop(Frame, Panel);
		refresh ->
			wxPanel:refresh(Panel),	
			loop(Frame, Panel);

		start -> ok;
		pause -> ok;
		restart -> ok;

		Event ->
			io:format("event: ~p~n", [Event]),
			loop(Frame, Panel)
	end.
	
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DRAW OBJECTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
draw_field(DC) ->
	Pen = wxPen:new(),
	X = ?BORDER,
	Y = ?BORDER,
	DX = ?FIELD_SIZE,
	DY = ?FIELD_SIZE,
	wxPen:setWidth(Pen, 2),
	wxPen:setColour(Pen, ?wxBLACK),
	wxDC:setPen(DC, Pen),
	wxDC:drawRectangle(DC, {X, Y}, {DX, DY}).

get_x_coord(X) ->
	?BORDER + X*?CELLSIZE.

get_y_coord(Y) ->
	?BORDER + Y*?CELLSIZE.

%wxDC:setBrush(MemDC, ?wxMEDIUM_GREY_BRUSH),
%      wxDC:drawCircle(MemDC, {20, 20}, 7)
	
draw_piton_head(DC, Piton) ->
	[{PX, PY}|_] = Piton,
	X = get_x_coord(PX),
	Y = get_y_coord(PY),
	Pen = wxPen:new(),
	wxPen:setWidth(Pen, 1),
	wxPen:setColour(Pen, ?wxRED),
	wxDC:setPen(DC, Pen),
	wxDC:drawRectangle(DC, {X, Y}, {?CELLSIZE, ?CELLSIZE}).
	
draw_piton_body(DC, Piton) ->
	[_|Body] = Piton,
	draw_piton_body1(DC, Body).

draw_piton_body1(DC, []) -> ok;
	
draw_piton_body1(DC, Body) ->
	[First|Rest] = Body,
	{PX, PY} = First,
	X = get_x_coord(PX),
	Y = get_y_coord(PY),
	Pen = wxPen:new(),
	wxPen:setWidth(Pen, 1),
	wxPen:setColour(Pen, ?wxGREEN),
	wxDC:setPen(DC, Pen),
	wxDC:drawRectangle(DC, {X, Y}, {?CELLSIZE, ?CELLSIZE}),
	draw_piton_body1(DC, Rest).
	
draw_piton(DC, Piton) ->
	draw_piton_head(DC, Piton),
	draw_piton_body(DC, Piton).

draw_gui(Panel) ->
	DC = wxPaintDC:new(Panel),
	draw_field(DC),
	pitonPid ! {request_piton_state, self()},
	receive
		{piton_state, Piton} ->
			draw_piton(DC, Piton),
			ok
	end,
	wxPaintDC:destroy(DC).

	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN FUNCTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
run() ->
	%% 3 processes will be run: Gui/field, piton, items
	Piton = piton_init(),
	register(pitonPid, spawn(?MODULE, piton_run_cycle, [Piton, up, false, 1000])),
	register(fieldPid, self()),
	Items = items_init(),
	register(itemsPid, spawn(?MODULE, items_loop, [Items])),
	
	Wx = wx:new(),
	Frame = create_window(Wx),
	Panel = wxPanel:new(Frame),
	wxFrame:connect(Panel, paint, [{callback, fun(_Evt, _Obj) -> draw_gui(Panel) end }]),
	wxFrame:connect(Panel, key_up), 
	wxFrame:connect(Frame, close_window),
	wxFrame:connect(Frame, command_menu_selected), 
	wxFrame:show(Frame),
	
	loop(Frame, Panel),
	pitonPid ! stop,
	itemsPid ! stop,
	wx:destroy(),
	ok.
