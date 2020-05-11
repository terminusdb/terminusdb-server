:- module(db_fast_forward, [
%              fast_forward_branch/4
          ]).

:- use_module(core(util)).
:- use_module(core(query)).
:- use_module(core(transaction)).

fast_forward_branch(Our_Branch_Descriptor, Their_Branch_Descriptor, Applied_Commit_Ids) :-
    Our_Repo_Descriptor = Our_Branch_Descriptor.repository_descriptor,
    Their_Repo_Descriptor = Their_Branch_Descriptor.repository_descriptor,
    create_context(Our_Repo_Descriptor, Our_Repo_Context),
    create_context(Their_Repo_Descriptor, Their_Repo_Context),
    with_transaction(Our_Repo_Context,
                     (
                         (   branch_head_commit(Our_Repo_Context, Our_Branch_Descriptor.branch_name, Our_Commit_Uri)
                         % our branch has a previous commit, so we have to find the common ancestor with their branch
                         % This common ancestor should be our own head, so we need to check for divergent history and error in that case.
                         ->  commit_id_uri(Our_Repo_Context, Our_Commit_Id, Our_Commit_Uri),
                             (   branch_head_commit(Their_Repo_Context, Their_Branch_Descriptor.branch_name, Their_Commit_Uri)
                             ->  commit_id_uri(Their_Repo_Context, Their_Commit_Id, Their_Commit_Uri),
                                 most_recent_common_ancestor(Our_Repo_Context, Their_Repo_Context, Our_Commit_Id, Their_Commit_Id, _Common_Commit_Id, Our_Branch_Path, Their_Branch_Path),
                                 (   Our_Branch_Path = []
                                 ->  true
                                 ;   throw(error(fast_forward_divergent_history))),

                                 Applied_Commit_Ids = Their_Branch_Path,
                                 Next = copy_commit(Their_Commit_Id))
                         ;   (   branch_head_commit(Their_Repo_Context, Their_Branch_Descriptor.branch_name, Their_Commit_Uri)
                             ->  commit_id_uri(Their_Repo_Context, Their_Commit_Id, Their_Commit_Uri),
                                 commit_uri_to_history_commit_ids(Their_Repo_Context, Their_Commit_Uri, Applied_Commit_Ids),
                                 Next = copy_commit(Their_Commit_Id)
                             ;   Next = nothing)),

                         (   Next = copy_commit(Commit_Id)
                         ->  copy_commits(Their_Repo_Context, Our_Repo_Context, Commit_Id),
                             branch_name_uri(Our_Repo_Context, Our_Branch_Descriptor.branch_name, Our_Branch_Uri),
                             ignore(unlink_commit_object_from_branch(Our_Repo_Context, Our_Branch_Uri)),
                             commit_id_uri(Our_Repo_Context, Commit_Id, Commit_Uri),
                             link_commit_object_to_branch(Our_Repo_Context, Our_Branch_Uri, Commit_Uri)
                         ;   true)),
                     _).

:- begin_tests(fast_forward_api).
:- use_module(core(util/test_utils)).
:- use_module(core(query)).
:- use_module(core(triple)).

:- use_module(db_init).
:- use_module(db_branch).
test(fast_forward_empty_branch_from_same_repo,
     [setup((setup_temp_store(State),
             create_db('user|foo','test','a test', 'terminus://blah'))),
      cleanup(teardown_temp_store(State))
     ])
:-
    resolve_absolute_string_descriptor("user/foo", Master_Descriptor),

    % create a branch off the master branch (which should result in an empty branch)
    branch_create(Master_Descriptor.repository_descriptor, Master_Descriptor, "second", [], _),

    resolve_absolute_string_descriptor("user/foo/local/branch/second", Second_Descriptor),

    % create two commits on the new branch
    create_context(Second_Descriptor, commit_info{author:"test",message:"commit a"}, Second_Context_1),
    with_transaction(Second_Context_1,
                     ask(Second_Context_1,
                         insert(a,b,c)),
                     _),
    create_context(Second_Descriptor, commit_info{author:"test",message:"commit b"}, Second_Context_2),
    with_transaction(Second_Context_2,
                     ask(Second_Context_2,
                         insert(d,e,f)),
                     _),

    % fast forward master with second
    fast_forward_branch(Master_Descriptor, Second_Descriptor, Applied_Commit_Ids),

    % check history
    Repo_Descriptor = (Master_Descriptor.repository_descriptor),
    branch_head_commit(Repo_Descriptor, "master", Head_Commit_Uri),
    commit_uri_to_history_commit_ids(Repo_Descriptor, Head_Commit_Uri, History),
    History = [Commit_A, Commit_B],
    History = Applied_Commit_Ids,

    commit_id_to_metadata(Repo_Descriptor, Commit_A, _, "commit a", _),
    commit_id_to_metadata(Repo_Descriptor, Commit_B, _, "commit b", _).

test(fast_forward_nonempty_branch_from_same_repo,
     [setup((setup_temp_store(State),
             create_db('user|foo','test','a test', 'terminus://blah'))),
      cleanup(teardown_temp_store(State))
     ])
:-
    resolve_absolute_string_descriptor("user/foo", Master_Descriptor),

    % create single commit on master branch
    create_context(Master_Descriptor, commit_info{author:"test",message:"commit a"}, Master_Context),
    with_transaction(Master_Context,
                     ask(Master_Context,
                         insert(a,b,c)),
                     _),

    % create a branch off the master branch
    branch_create(Master_Descriptor.repository_descriptor, Master_Descriptor, "second", [], _),

    resolve_absolute_string_descriptor("user/foo/local/branch/second", Second_Descriptor),

    % create two commits on the new branch
    create_context(Second_Descriptor, commit_info{author:"test",message:"commit b"}, Second_Context_1),
    with_transaction(Second_Context_1,
                     ask(Second_Context_1,
                         insert(d,e,f)),
                     _),
    create_context(Second_Descriptor, commit_info{author:"test",message:"commit c"}, Second_Context_2),
    with_transaction(Second_Context_2,
                     ask(Second_Context_2,
                         insert(g,h,i)),
                     _),

    % fast forward master with second
    fast_forward_branch(Master_Descriptor, Second_Descriptor, Applied_Commit_Ids),

    % check history
    Repo_Descriptor = (Master_Descriptor.repository_descriptor),
    branch_head_commit(Repo_Descriptor, "master", Head_Commit_Uri),
    commit_uri_to_history_commit_ids(Repo_Descriptor, Head_Commit_Uri, History),
    History = [Commit_A, Commit_B, Commit_C],
    Applied_Commit_Ids = [Commit_B, Commit_C],


    commit_id_to_metadata(Repo_Descriptor, Commit_A, _, "commit a", _),
    commit_id_to_metadata(Repo_Descriptor, Commit_B, _, "commit b", _),
    commit_id_to_metadata(Repo_Descriptor, Commit_C, _, "commit c", _).

:- end_tests(fast_forward_api).
