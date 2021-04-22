:- module(literals, [
              literal_to_turtle/2,
              normalise_triple/2,
              object_storage/2,
              ground_object_storage/2,
              storage_object/2,
              date_string/2,
              date_time_string/2,
              time_string/2,
              duration_string/2,
              gyear_string/2,
              gmonth_string/2,
              gyear_month_string/2,
              gmonth_day_string/2,
              gday_string/2,
              uri_to_prefixed/3,
              prefixed_to_uri/3
          ]).

/** <module> Literals
 *
 * Literal handling
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

:- reexport(core(util/syntax)).
:- use_module(library(pcre)).
:- use_module(core(util)).
:- use_module(core(triple/casting), [typecast/4]).
:- use_module(core(validation), [basetype_subsumption_of/2]).

/*
 * date_time_string(-Date_Time,+String) is det.
 * date_time_string(+Date_Time,-String) is det.
 */
date_time_string(Date_Time,String) :-
    nonvar(Date_Time),
    !,
    % ToDo, add appropriate time zone! Doesn't work in xsd_time_string!
    Date_Time = date_time(Y,M,D,HH,MM,SS),
    (   integer(SS)
    ->  format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+T~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+Z',
               [Y,M,D,HH,MM,SS])
    ;   S is floor(SS),
        MS is floor((SS - S) / 1000),
        format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+T~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+.~|~`0t~d~3+Z',
               [Y,M,D,HH,MM,S,MS])
    ).
date_time_string(Date_Time,String) :-
    % So expensive! Let's do this faster somehow.
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:dateTime(Y,M,D,HH,MM,SS,Offset),Codes),
    datetime_to_internal_datetime(date(Y,M,D,HH,MM,SS,Offset,-,-), Date_Time).


date_time_stamp_string(Date_Time,String) :-
    nonvar(Date_Time),
    !,
    % ToDo, add appropriate time zone! Doesn't work in xsd_time_string!
    Date_Time = date_time(Y,M,D,HH,MM,SS),
    (   integer(SS)
    ->  format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+T~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+Z',
               [Y,M,D,HH,MM,SS])
    ;   S is floor(SS),
        MS is floor((SS - S) / 1000),
        format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+T~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+.~|~`0t~d~3+Z',
               [Y,M,D,HH,MM,S,MS])
    ).
date_time_stamp_string(Date_Time,String) :-
    % So expensive! Let's do this faster somehow.
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:dateTimeStamp(Y,M,D,HH,MM,SS,Offset),Codes),
    datetime_to_internal_datetime(date(Y,M,D,HH,MM,SS,Offset,-,-), Date_Time).

/*
 * date_string(-Date,+String) is det.
 * date_string(+Date,-String) is det.
 */
date_string(Date,String) :-
    nonvar(Date),
    !,
    % ToDo, add appropriate time zone! Doesn't work in xsd_time_string!
    Date = date(Y,M,D,Offset),
    (   Offset =:= 0
    ->  format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+',
               [Y,M,D])
    ;   offset_to_sign_hour_minute(Offset, Sign, Hour, Minute),
        format(string(String),
               '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+~w~|~`0t~d~2+:~|~`0t~d~2+',
               [Y,M,D, Sign, Hour, Minute])
    ).
date_string(date(Y,M,D,Offset),String) :-
    % So expensive! Let's do this faster somehow.
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:date(Y,M,D,Offset),Codes).

gyear_string(GYear, String) :-
    nonvar(GYear),
    !,
    GYear = gyear(Year,Offset),
    (   Offset =:= 0
    ->  format(string(String), '~|~`0t~d~4+', [Year])
    ;   offset_to_sign_hour_minute(Offset,Sign,Hour,Minute),
        format(string(String), '~|~`0t~d~4+~|~`0t~d~2+:~|~`0t~d~2+', [Year,Sign,Hour,Minute])
    ).
gyear_string(gyear(Year,Offset), String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:gYear(Year,Offset),Codes).

gmonth_string(GMonth, String) :-
    nonvar(GMonth),
    !,
    GMonth = gmonth(Month,Offset),
    (   Offset =:= 0
    ->  format(string(String), '--~|~`0t~d~2+', [Month])
    ;   offset_to_sign_hour_minute(Offset,Sign,Hour,Minute),
        format(string(String), '--~|~`0t~d~2+~w~|~`0t~d~2+:~|~`0t~d~2+', [Month,Sign,Hour,Minute])
    ).
gmonth_string(gmonth(Month,Offset), String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:gMonth(Month,Offset),Codes).


gyear_month_string(GYearMonth, String) :-
    nonvar(GYearMonth),
    !,
    GYearMonth = gyear_month(Year,Month,Offset),
    (   Offset =:= 0
    ->  format(string(String), '~|~`0t~d~4+-~|~`0t~d~2+', [Year,Month])
    ;   offset_to_sign_hour_minute(Offset,Sign,Hour,Minute),
        format(string(String), '~|~`0t~d~4+-~|~`0t~d~2+~|~`0t~d~2+:~|~`0t~d~2+', [Year,Month,Sign,Hour,Minute])
    ).
gyear_month_string(gyear_month(Year,Month,Offset), String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:gYearMonth(Year,Month,Offset),Codes).

gmonth_day_string(GMonthDay, String) :-
    nonvar(GMonthDay),
    !,
    GMonthDay = gmonth_day(Month,Day,Offset),
    (   Offset =:= 0
    ->  format(string(String), '-~|~`0t~d~2+-~|~`0t~d~2+', [Month,Day])
    ;   offset_to_sign_hour_minute(Offset,Sign,Hour,Minute),
        format(string(String), '-~|~`0t~d~2+-~|~`0t~d~2+~w~|~`0t~d~2+:~|~`0t~d~2+', [Month,Day,Sign,Hour,Minute])
    ).
gmonth_day_string(gmonth_day(Month,Day,Offset), String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:gMonthDay(Month,Day,Offset),Codes).

gday_string(GDay, String) :-
    nonvar(GDay),
    !,
    GDay = gday(Day,Offset),
    (   Offset =:= 0
    ->  format(string(String), '---~|~`0t~d~2+', [Day])
    ;   offset_to_sign_hour_minute(Offset,Sign,Hour,Minute),
        format(string(String), '---~|~`0t~d~2+~w~|~`0t~d~2+:~|~`0t~d~2+', [Day,Sign,Hour,Minute])
    ).
gday_string(gday(Day,Offset), String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:gDay(Day,Offset),Codes).

offset_to_sign_hour_minute(Offset, Sign, Hour, Minute) :-
    nonvar(Offset),
    !,
    H_Off is Offset / 3600,
    M_Off is (Offset - (H_Off * 3600)) / 60,
    (   Offset >= 0
    ->  Sign = '+',
        Hour = H_Off,
        Minute = M_Off
    ;   Sign = '-',
        Hour is -H_Off,
        Minute is -M_Off).

/*
 * time_string(-Time,+String) is det.
 * time_string(+Time,-String) is det.
 */
time_string(Time,String) :-
    nonvar(Time),
    !,
    % ToDo, add appropriate time zone! Doesn't work in xsd_time_string!
    Time = time(HH,MM,SS),
    (   integer(SS)
    ->  format(string(String),
               '~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+Z',
               [HH,MM,SS])
    ;   S is floor(SS),
        MS is floor((SS - S) / 1000),
        format(string(String),
               '~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+.~|~`0t~d~3+Z',
               [HH,MM,S,MS])
    ).
time_string(Time,String) :-
    % So expensive! Let's do this faster somehow.
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:time(HH,MM,SS,Offset),Codes),
    time_to_internal_time(time(HH,MM,SS,Offset),Time).

duration_string(Duration,String) :-
    nonvar(Duration),
    !,
    Duration = duration(S,Y,M,D,HH,MM,SS),
    (   S = 1
    ->  SP = ''
    ;   SP = '-'),
    (   Y \= 0
    ->  format(atom(YP),'~wY',[Y])
    ;   YP = ''),
    (   M \= 0
    ->  format(atom(MP),'~wM',[M])
    ;   MP = ''),
    (   D \= 0
    ->  format(atom(DP),'~wD',[D])
    ;   DP = ''),
    (   \+ (HH =:= 0, MM =:= 0, SS =:= 0)
    ->  TP = 'T'
    ;   TP = ''),
    (   HH \= 0
    ->  format(atom(HHP),'~wH',[HH])
    ;   HHP = ''),
    (   MM \= 0
    ->  format(atom(MMP),'~wM',[MM])
    ;   MMP = ''),
    (   SS \= 0
    ->  format(atom(SSP),'~wS',[SS])
    ;   SSP = ''),
    atomic_list_concat([SP,'P',YP,MP,DP,TP,HHP,MMP,SSP],Atom),
    atom_string(Atom,String).
duration_string(duration(Sign,Y,M,D,HH,MM,SS),String) :-
    nonvar(String),
    !,
    atom_codes(String,Codes),
    phrase(xsd_parser:duration(Sign,Y,M,D,HH,MM,SS),Codes).

is_number_type(Type) :-
    (   Type = 'http://www.w3.org/2001/XMLSchema#float'
    ;   Type = 'http://www.w3.org/2001/XMLSchema#double'
    ;   basetype_subsumption_of(Type, 'http://www.w3.org/2001/XMLSchema#decimal')
    ).

/*
 * literal_to_turtle(+Literal,-Turtle_Literal) is det.
 *
 * Deal with precularities of rdf_process_turtle
 */
literal_to_turtle(String@Lang,literal(lang(Lang,S))) :-
    atom_string(S,String).
literal_to_turtle(Elt^^Type,literal(type(Type,S))) :-
    typecast(Elt^^Type, 'http://www.w3.org/2001/XMLSchema#string', [], Val^^_),
    atom_string(S,Val).

/*
 * turtle_to_literal(+Turtle_Literal,+Literal) is det.
 *
 * Deal with precularities of rdf_process_turtle
 */
turtle_to_literal(literal(lang(Lang,S)),String@Lang) :-
    (   atom(S)
    ->  atom_string(S,String)
    ;   S = String),
    !.
turtle_to_literal(literal(type(Type,A)),Val^^Type) :-
    atom_string(A,S),
    typecast(S^^'http://www.w3.org/2001/XMLSchema#string', Type, [], Val^^_),
    !.
turtle_to_literal(literal(L),String@en) :-
    (   atom(L)
    ->  atom_string(L,String)
    ;   L = String).

normalise_triple(rdf(X,P,Y),rdf(XF,P,YF)) :-
    (   X = node(N)
    ->  atomic_list_concat(['_:',N], XF)
    ;   X = XF),

    (   Y = node(M)
    ->  atomic_list_concat(['_:',M], YF)
    %   Bare atom literal needs to be lifted.
    ;   Y = literal(_)
    ->  turtle_to_literal(Y,YF)
    %   Otherwise walk on by...
    ;   Y = YF).

ground_object_storage(String@Lang, value(S)) :-
    !,
    format(string(S), '~q@~q', [String,Lang]).
ground_object_storage(Val^^Type, value(S)) :-
    !,
    (   is_number_type(Type)
    ->  format(string(S), '~q^^~q', [Val,Type])
    ;   typecast(Val^^Type, 'http://www.w3.org/2001/XMLSchema#string',
                 [], Cast^^_)
    ->  format(string(S), '~q^^~q', [Cast,Type])
    ;   format(string(S), '~q^^~q', [Val,Type])).
ground_object_storage(O, node(O)).

/*
 * We can only make a concrete referrent if all parts are bound.
 */
nonvar_literal(Atom@Lang, Literal) :-
    atom(Atom),
    !,
    atom_string(Atom, String),
    nonvar_literal(String@Lang, Literal).
nonvar_literal(Atom^^Type, Literal) :-
    atom(Atom),
    !,
    atom_string(Atom, String),
    nonvar_literal(String^^Type, Literal).
nonvar_literal(String@Lang, value(S)) :-
    nonvar(Lang),
    nonvar(String),
    !,
    format(string(S), '~q@~q', [String,Lang]).
nonvar_literal(Val^^Type, value(S)) :-
    nonvar(Type),
    nonvar(Val),
    !,
    (   is_number_type(Type)
    ->  format(string(S), '~q^^~q', [Val,Type])
    ;   typecast(Val^^Type, 'http://www.w3.org/2001/XMLSchema#string',
                 [], Cast^^_)
    ->  format(string(S), '~q^^~q', [Cast,Type])
    ;   format(string(S), '~q^^~q', [Val,Type])).
nonvar_literal(Val^^Type, _) :-
    once(var(Val) ; var(Type)),
    !.
nonvar_literal(Val@Lang, _) :-
    once(var(Val) ; var(Lang)),
    !.
nonvar_literal(O, node(S)) :-
    nonvar(O),

    atom_string(O,S).

object_storage(O,V) :-
    nonvar(O),
    !,
    nonvar_literal(O,V).
object_storage(_O,_V). % Do nothing if input is a variable

storage_atom(TS,T) :-
    var(T),
    !,
    TS = T.
storage_atom(TS,T) :-
    (   atom(T)
    ->  TS = T
    ;   atom_string(TS,T)).

storage_value(X,V) :-
    var(V),
    !,
    X = V.
storage_value(X,V) :-
    (   string(V)
    ->  X = V
    ;   atom_string(V,X)).

storage_literal(X1^^T1,X3^^T2) :-
    storage_atom(T1,T2),
    storage_value(X1,X2),
    (   is_number_type(T2)
    ->  (   string(X2)
        ->  do_or_die(
                number_string(X3,X2),
                error(not_a_valid_number_in_database_storage(X2),_)
            )
        ;   X2 = X3)
    % NOTE: This is considered special because the anyURI condition
    % used to be less strict.
    % There may be data in the DB that does not meet the current
    % datatype specification.
    ;   T2 = 'http://www.w3.org/2001/XMLSchema#anyURI'
    ->  X2 = X3
    ;   typecast(X2^^'http://www.w3.org/2001/XMLSchema#string',T2,
                 [], X3^^_)
    ).
storage_literal(X1@L1,X2@L2) :-
    storage_atom(L1,L2),
    storage_value(X1,X2).

/*
 * Too much unnecessary marshalling...
 */
storage_object(value(S),O) :-
    (   term_string(Term,S)
    ->  (   Term = X^^T
        ->  storage_literal(X^^T,O)
        ;   Term = X@Lang
        ->  storage_literal(X@Lang,O)
        ;   throw(error(storage_unknown_type_error(Term),_)))
    ;   throw(error(storage_bad_value(S),_))).
storage_object(node(S),O) :-
    (   nonvar(O)
    ->  (   atom(O)
        ->  atom_string(O,S)
        ;   O = S)
    ;   atom_string(O,S)).



try_prefix_uri(X,_,X) :-
    nonvar(X),
    X = _A:_B,
    !.
try_prefix_uri(URI,[],URI) :-
    !.
try_prefix_uri(URI,[Prefix-URI_Base|_], Prefixed) :-
    atom(URI_Base),
    escape_pcre(URI_Base,URI_Escaped),
    atomic_list_concat(['^(?P<base>',URI_Escaped,')(?P<rest>.*)$'], Pattern),
    re_matchsub(Pattern, URI, Match, []),
    atom_string(Suffix,Match.rest),
    Prefixed = Prefix : Suffix,
    !.
try_prefix_uri(URI,[_|Rest], Prefixed) :-
    try_prefix_uri(URI,Rest, Prefixed).

length_comp((<),A-_,B-_) :-
    string_length(A,N),
    string_length(B,M),
    N < M,
    !.
length_comp((>),A-_,B-_) :-
    string_length(A,N),
    string_length(B,M),
    N > M,
    !.
% choose lexical if length is identical
length_comp((<),A-_,B-_) :-
    A @< B,
    !.
length_comp((>),A-_,B-_) :-
    A @> B,
    !.
length_comp((=),_,_).

uri_to_prefixed(URI, Ctx, Prefixed) :-
    dict_pairs(Ctx,_,Pairs),
    predsort(length_comp, Pairs, Sorted_Pairs),
    try_prefix_uri(URI,Sorted_Pairs,Prefixed).

prefixed_to_uri(Prefix:Suffix, Ctx, URI) :-
    (    Base = Ctx.get(Prefix)
    ->   true
    ;    format(atom(M), "Could not convert prefix to URI: ~w", [Prefix]),
         throw(prefix_error(M))),
    !,
    atomic_list_concat([Base, Suffix], URI).
prefixed_to_uri(URI, _, URI).


:- begin_tests(turtle_literal_marshalling).

test(date, []) :-
    literal_to_turtle(date_time(-228, 10, 10, 0, 0, 0)^^'http://www.w3.org/2001/XMLSchema#dateTime', literal(type('http://www.w3.org/2001/XMLSchema#dateTime','-228-10-10T00:00:00Z'))).

test(bool, []) :-
    literal_to_turtle(false^^'http://www.w3.org/2001/XMLSchema#boolean', literal(type('http://www.w3.org/2001/XMLSchema#boolean',false))).

test(double, []) :-
    literal_to_turtle(33.4^^'http://www.w3.org/2001/XMLSchema#double', literal(type('http://www.w3.org/2001/XMLSchema#double','33.4'))).

:- end_tests(turtle_literal_marshalling).

:- begin_tests(marshall_bad_data).
:- use_module(core(util/test_utils)).
:- use_module(core(query)).
:- use_module(core(transaction)).
:- use_module(library(terminus_store)).

test(bad_number_data, [setup((setup_temp_store(State),
                           create_db_without_schema("admin","foo"))),
                       cleanup(teardown_temp_store(State)),
                       error(not_a_valid_number_in_database_storage("asdf fdsa"),_)]) :-

    resolve_absolute_string_descriptor("admin/foo", Descriptor),
    create_context(Descriptor, commit_info{author:"test", message:"test"}, Context),
    [Transaction] = (Context.transaction_objects),
    [RWO] = (Transaction.instance_objects),
    read_write_obj_builder(RWO,Builder),

    with_transaction(
        Context,
        (   nb_add_triple(Builder, "a", "b",
                          value("\"asdf fdsa\"^^'http://www.w3.org/2001/XMLSchema#double'"))
        ),
        _Meta_Data
    ),

    once(
        ask(Descriptor, (t(a,b,_)))).


test(bad_url_data, [setup((setup_temp_store(State),
                           create_db_without_schema("admin","foo"))),
                    cleanup(teardown_temp_store(State))]) :-

    resolve_absolute_string_descriptor("admin/foo", Descriptor),
    create_context(Descriptor, commit_info{author:"test", message:"test"}, Context),
    [Transaction] = (Context.transaction_objects),
    [RWO] = (Transaction.instance_objects),
    read_write_obj_builder(RWO,Builder),

    with_transaction(
        Context,
        (   nb_add_triple(Builder, "a", "b",
                          value("\"asdf fdsa\"^^'http://www.w3.org/2001/XMLSchema#anyURI'"))
        ),
        _Meta_Data
    ),

    once(
        ask(Descriptor, (t(a,b,"asdf fdsa"^^xsd:anyURI)))).

:- end_tests(marshall_bad_data).
