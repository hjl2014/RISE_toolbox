function [obj,retcode,structural_matrices]=solve(obj,varargin)
% solve - solves dsge model
%
% Syntax
% -------
% ::
%
%   [obj,retcode,structural_matrices]=solve(obj)
%
%   [obj,retcode,structural_matrices]=solve(obj,varargin)
%
% Inputs
% -------
%
% - **obj** [rise|dsge]: scalar or vector of model objects. The optional
% options below come in pairs.
%
% - **solve_accelerate** [{false}|true]: Accelerate or do not accelerate
% the solving
%
% - **solve_check_stability** [{true}|false]: check stability of Markov
% switching models while solving. The stability of constant-parameter
% models is always checked whether that of markov-switching models is
% optional. This is because (1) the procedure is computationally intensive
% and (2) there is no define stability criterion under endogenous switching
%
% - **solve_derivatives_type** [numeric|automatic|{symbolic}]: choice of
% derivatives
%
% - **solve_disable_theta** [true|{false}]: option for nullifying the
% effect of future switching parameters on the solution
%
% - **solve_order** [integer|{1}]: order of approximation
%
% - **solve_shock_horizon** [integer|{0}|struct|cell]: anticipation horizon
% of shocks beyond the current period. When the input is :
%   - an integer : all the shocks receive the same anticipation horizon
%   - a struct : the fields are the names of the shocks whose horizon is to
%   be modified. e.g. struct('ea',4,'eb',3) means shock ea has horizon 4
%   while shock eb has horizon 3
%   - a cell : the cell must have two colums. Each row in the first column
%   holds the name of a particular shock and each row in the second column
%   holds the horizon of the shock. e.g. {'ea',4;'eb',3}
%
% - **solve_alternatives_file2save2** [{[]}|char]: name of the file to
% write the results of the alternative solutions
%
% - **solve_alternatives_nsim** [integer|{100}]: Number of initial guesses
% for the solution sampled randomly, when attempting to find all possible
% solutions.
%
%  - **solve_function_mode** [{explicit/amateur}|vectorized/professional|disc]
%   - in the **amateur** or **explicit** mode the functions are kept in
%   cell arrays of anonymous functions and evaluated using for loops
%   - in the **vectorized** or **professional** mode the functions are
%   compacted into one long and unreadable function.
%   - in the **disc** mode the functions are written to disc in a
%   subdirectory called routines.
%
% - **solve_initialization** [{'backward'}|'zeros'|'random']: Type of
% initialization of the solution of switching models:
%   - **backward** : the initial guess is the solution of the model without
%   forward-looking terms
%   - **zeros** : the initial guess is zero
%   - **random** : the initial guess is random
%
% - **solver** [{[]}|char|user_defined]: solver for the dsge model. The
% following are possible:
%   - **loose_commitment** : RISE automatically uses this when it detects
%   an optimal policy model to be solved under commitment, discretion or
%   loose commitment
%   - **rise_1** : default solver for constant-parameter dsge models.
%   Similar to the dynare solver.
%   - **mfi** : functional interation solver: default for switching dsge
%   models
%   - **mnk** : newton solver with kronecker products
%   - **mn** : newton solver without kronecker products
%   - **mfi_full** : full version of mfi, that does not exploit sparsity
%   - **mnk_full** : full version of mnk, that does not exploit sparsity
%   - **mn_full** : full version of mn, that does not exploit sparsity
%   - **fwz** : Farmer, Waggoner and Zha (2011) solver
%   - **user_defined** : In this case the function must take as inputs:
%       - **Gplus01** [h x h cell]: each cell contains the matrices of
%       forward-looking terms associated with moving from one regime to
%       another.
%       - **A0** [square matrix]: matrix of contemporaneous variables
%       - **Aminus** [square matrix]: matrix of backward-looking terms
%       - **Q** [square matrix]: transition matrix, in which the rows are
%       the current period and the columns the next period
%       - **T0** [square matrix]: initial guess of the solution
%     The function should return as outputs
%       - **Tz_pb** [square matrix]: solution of the problem given the
%       inputs
%       - **eigenvalues** [empty|vector]: optional vector of eigenvalues of
%       the problem
%       - **retcode** : 0 if no problem found when solving the problem
%
% - **solve_log_approx_vars** [char|cellstr|{[]}]: List of variables for
% which we want to take a log expansion (x_t-x_ss)/x_ss, which approximates
% log(x_t/x_ss) for x_t/x_ss close to 1.
%
% Outputs
% --------
%
% - **obj** [rise|dsge]: scalar or vector of model objects
%
% - **retcode** [integer]: if 0, no problem was found when solving the
% model. If positive, the reason for the problem can be obtained by running
% decipher(retcode)
%
% - **structural_matrices** [struct]: Structure holding various types of
% derivatives that are used in the computation of the solution
%
% More About
% ------------
%
% - constant-parameter models can also be solved using the procedures for
% switching parameter models. There is no guarantee, however, any obtained
% solution will be determinate (unique and stable)
%
% - determinacy is only checked for constant-parameter models. For
% determinacy computations for switching dsge models with constant
% transition matrices, see Cho(2014).
%
% - In RISE we consider that it is in the nature of nonlinear models to
% have many solutions. Obtaining even one of those solution is usually
% difficult and a concept such as determinacy is NEVER used in the solving
% of models with, say, global methods.
%
% Examples
% ---------
%
% See also:

% I should formally check that all the variables that enter the calculation
% of endogenous probabilities have a unique steady state. I can add a flag
% into the endogenous that says whether a variables enters the endogenous
% probabilities or not. Instead of always loading the first column of the
% steady state when evaluating endogenous probabilities as I think I do in
% the beta version of RISE.

% anticipation_order=1
% solve_order = 1
% resolve if any of those has changed:
% - params,
% - solve_order: if a higher order has previously been solved, no need to >
% - anticipation_order, if a higher order has previously been solved, no need to >
% - solution algorithm,
% - etc...

if isempty(obj)
    if nargout>1
        error([mfilename,':: when the object is emtpy, nargout must be at most 1'])
    end
    obj=utils.miscellaneous.mergestructures(optimal_policy_solver_h(obj),...
        dsge_solver_h(obj),...
        struct('solver',[],...
        'solve_order',1,...
        'solve_check_stability',true,...
        'solve_derivatives_type','symbolic',...%['symbolic','numerical','automatic']
        'solve_accelerate',false,...
        'solve_function_mode','explicit',... %['explicit','disc','vectorized'] see dsge.set
        'solve_shock_horizon',[],...
        'solve_log_approx_vars',[]));%
    return
end

if ~isempty(varargin)
    obj=set(obj,varargin{:});
end
nobj=numel(obj);
if nobj>1
    retcode=nan(1,nobj);
    structural_matrices=cell(1,nobj);
    nout=nargout;
    for iobj=1:nobj
        if nout<3
            [obj(iobj),retcode(iobj)]=solve(obj(iobj),varargin{:});
        else
            [obj(iobj),retcode(iobj),structural_matrices{iobj}]=solve(obj(iobj),varargin{:});
        end
    end
    return
end

% initialize elements that will be used by different sub-functions
%-----------------------------------------------------------------
def=[];
ys=[];
ss=[];
nx=sum(obj.exogenous.number);
xss=zeros(nx,1);
[the_leads,the_current,the_lags,indices,nind,endo_nbr]=create_indices(obj.lead_lag_incidence.before_solve);
structural_matrices=[];

if obj.is_optimal_policy_model % || obj.estimation_under_way
    obj.options.solve_order=1;
end
solve_order=obj.options.solve_order;
params=obj.parameter_values;
resolve_it=check_whether_to_resolve();
h=obj.markov_chains.small_markov_chain_info.regimes_number;

% solve zeroth order or steady state ... and measurement errors
%--------------------------------------------------------------
retcode=solve_zeroth_order();
if solve_order>0 && ~retcode && resolve_it
    % the parameters may have changed during the computation of the zeroth
    % order or steady state. That is why they are reloaded here
    params=obj.parameter_values;
    
    % evaluate all the derivatives up to the desired order: analytical
    % derivatives can be evaluated sequentially, but for algorithmic
    % derivatives and for numerical derivatives, it is more economical to
    % do them at once, instead of calling the same functions several times
    %---------------------------------------------------------------------
    retcode=evaluate_all_derivatives();
    if ~retcode
        if obj.is_optimal_policy_model
            [T,eigval,zmultcols,retcode]=optimal_policy_solver_h(obj,structural_matrices);
            % expand solution to account for loose commitment
            %------------------------------------------------
            loose_com_col=find(strcmp(obj.markov_chains.chain_names,parser.loose_commit));
            if ~retcode && ~isempty(loose_com_col)
                big_regimes=cell2mat(obj.markov_chains.regimes(2:end,2:end));
                small_regimes=cell2mat(obj.markov_chains.small_markov_chain_info.regimes(2:end,2:end));
                bigh=obj.markov_chains.regimes_number;
                loose_com_regimes=big_regimes(:,loose_com_col);
                big_regimes(:,loose_com_col)=[];
                Tz=cell(1,bigh);
                % including the definitions, the steady state, etc.
                %--------------------------------------------------
                ss_=Tz;
                def_=Tz;
                bgp_=Tz;
                for ireg=1:bigh
                    bingo=all(bsxfun(@minus,big_regimes(ireg,:),small_regimes)==0,2);
                    Tsol=T.Tz{bingo};
                    if loose_com_regimes(ireg)==2 && ... % discretion: set multipliers to zero
                            ~obj.options.lc_reconvexify; % under reconvexification, we do not zero the multipliers
                        Tsol(:,zmultcols)=0;
                    end
                    Tz{ireg}=Tsol;
                    def_{ireg}=obj.solution.definitions{bingo};
                    ss_{ireg}=obj.solution.ss{bingo};
                    bgp_{ireg}=obj.solution.bgp{bingo};
                end
                obj.solution.definitions=def_;
                obj.solution.ss=ss_;
                obj.solution.bgp=bgp_;
                T.Tz=Tz;
            end
            % set the name of the solver
            %---------------------------
            if isempty(obj.options.solver)
                obj.options.solver='loose_commitment';
            end
        else
            [T,eigval,retcode,obj]=dsge_solver_h(obj,structural_matrices);
            % options may have changed and so we re-collect obj
        end
        inv_order_var=obj.inv_order_var.after_solve;
        if ~retcode
            % Take the log approximation if required
            solve_log_approx_vars=obj.options.solve_log_approx_vars;
            if ~isempty(solve_log_approx_vars)
                retcode=log_expansion();
            end
            if ~retcode
                T_fields=fieldnames(T);
                nregs=numel(T.Tz);
                for ifield_=1:numel(T_fields)
                    fname=T_fields{ifield_};
                    % re-order the rows right here, right now
                    %----------------------------------------
                    for ireg=1:nregs
                        T.(fname){ireg}=T.(fname){ireg}(inv_order_var,:);
                    end
                    obj.solution.(fname)=T.(fname);
                end
                obj.solution.eigval=eigval;
                
                obj=set_z_eplus_horizon(obj);
                obj.solution.user_resids=structural_matrices.user_resids;
            end
        end
    end
end
if retcode && obj.options.debug
    utils.error.decipher(retcode)
end

    function retcode=evaluate_all_derivatives()
        % evaluate first-order derivatives
        %---------------------------------
        symbolic_type=strcmp(obj.options.solve_derivatives_type,'symbolic');
        if ~symbolic_type
            automatic_type=strcmp(obj.options.solve_derivatives_type,'automatic');
            if ~automatic_type
                numeric_type=any(strcmp(obj.options.solve_derivatives_type,{'numeric','numerical'}));
                if ~numeric_type
                    error(['solve_derivatives_type can only assume values ',...
                        '"symbolic", "automatic" or "numeric"'])
                end
                if solve_order>1
                    error('numerical derivatives not implemented for orders greater than 1')
                end
                % prepare the re-ordering of the endogenous columns
                reordering=obj.lead_lag_incidence.before_solve(obj.order_var.before_solve,:);
                reordering=reordering(reordering>0);
            end
        end
        
        xxx=repmat('v',1,solve_order);
        % evaluate higher-order derivatives
        %----------------------------------
        retcode=0;
        G01=cell(1,solve_order);
        for s1=1:h
            sparam=params(:,s1);
            for s0=1:h
                if ~retcode
                    % Note: G(s0,s1) =: ps0(s0,s1)*F(s0)
                    if symbolic_type
                        [G01{1:solve_order}]=utils.code.evaluate_functions(obj.routines.probs_times_dynamic_derivatives,...
                            ys(:,s0),xss,ss(:,s0),params(:,s0),sparam,def{s0},s0,s1);
                    elseif automatic_type
                        G01=utils.code.evaluate_automatic_derivatives(...
                            obj.routines.symbolic.probs_times_dynamic,solve_order,...
                            ys(:,s0),xss,ss(:,s0),params(:,s0),sparam,def{s0},s0,s1);
                    else
                        [G01{1:1}]=utils.code.evaluate_jacobian_numerically(obj.routines.probs_times_dynamic,...
                            ys(:,s0),xss,ss(:,s0),params(:,s0),sparam,def{s0},s0,s1,...
                            obj.switching_parameters_leads_index);
                        % The columns are to be put in the order_var order
                        G01{1}(:,1:nind)=G01{1}(:,reordering);
                    end
                    if utils.error.valid(G01)
                        % use the derivatives Gi to build dv, dvv, dvvv, ...
                        %---------------------------------------------------
                        for io=1:solve_order
                            if ~symbolic_type
                                [nr,nc]=size(G01{io});
                                G01{io}=sparse(reshape(G01{io},nr,nc));
                            end
                            structural_matrices.(['d',xxx(1:io)]){s0,s1}=G01{io};%
                        end
                    else
                        retcode=2; % nans in jacobian
                    end
                end
            end
        end
        % Compute planner information first
        %----------------------------------
        if obj.is_optimal_policy_model || obj.is_optimal_simple_rule_model
            planner=struct(...
                'objective',{cell(1,h)},...
                'commitment',{cell(1,h)},...
                'discount',{cell(1,h)},...
                'weights',{cell(1,h)}...
                );
            orig_endo_nbr=obj.endogenous.number(1);
            for s0=1:h
                if ~retcode
                    lcd=utils.code.evaluate_functions(...
                        obj.routines.planner_loss_commitment_discount,...
                        ss(:,s0),xss,ss(:,s0),params(:,s0),def{s0},s0,s0);
                    if ~utils.error.valid(lcd)
                        retcode=6;
                    end
                    if ~retcode
                        s1=s0;
                        % pick the hessian directly
                        order__=2;
                        if symbolic_type
                            [~,weights]=utils.code.evaluate_functions(...
                                obj.routines.planner_objective_derivatives,...
                                ss(:,s0),xss,ss(:,s0),params(:,s0),def{s0},s0,s1);
                        elseif automatic_type
                            D01=utils.code.evaluate_automatic_derivatives(...
                                obj.routines.symbolic.planner_objective,order__,...
                                ss(:,s0),xss,ss(:,s0),params(:,s0),[],def{s0},s0,s1);
                            weights=D01{order__};
                        else
                            weights=utils.code.evaluate_policy_objective_hessian_numerically(...
                                obj.routines.planner_objective,...
                                ss(:,s0),[],ss(:,s0),params(:,s0),[],def{s0},s0,s1);
                            % here the weights have to be re-ordered,
                            % unlike in the other cases, where it is done
                            % by the order of differentiation
                            weights=weights(obj.order_var.before_solve,obj.order_var.before_solve);
                        end
                        if ~utils.error.valid(weights)
                            retcode=6;
                        end
                        if ~retcode
                            planner.objective{s0}=lcd(1);
                            planner.commitment{s0}=lcd(2);
                            planner.discount{s0}=lcd(3);
                            planner.weights{s0}=sparse(reshape(weights,orig_endo_nbr,orig_endo_nbr));
                        end
                    end
                end
            end
            structural_matrices.planner=planner;
            % change the ordering of the weight for the user. OSR will use
            % the structural matrices, which are ordered according to
            % order_var
            iov=obj.inv_order_var.before_solve;
            for s0=1:h
                planner.weights{s0}=planner.weights{s0}(iov,iov);
            end
            obj.solution.planner=planner; clear planner
        end
    end
    function resolve_it=check_whether_to_resolve()
        % forward expansion order
        % if order==0, it means there is no ancitipation. It does not mean
        % that there no shocks. If order==0, this will later on help set
        % the conditional information to nan. But for the purpose of
        % expanding the model, the expansion order is at least 1.
        % NORMALLY ALL OPTIONS SHOULD BE CHECKED. FOR INSTANCE ONE MAY WANT
        % TO SEE THE EFFECT OF CHANGING THE TOLERANCE LEVEL ON THE SOLUTION
        % AND CURRENTLY, THIS IS NOT TAKEN CARE OF. AT SOME LEVEL, ALL THE
        % OPTIONS COULD BE REPRESENTED IN A VECTOR, SO THAT IF AN ELEMENT
        % IS DIFFERENT, WHATEVER IT IS, THEN WE RESOLVE. BUT THIS IS NOT AN
        % URGENT MATTER.
        resolve_it=isempty(obj.current_solution_state)||...
            obj.estimation_under_way||...
            strcmp(obj.options.solve_initialization,'random')||...
            ~isfield(obj.solution,'Tz');
        horizon=max(obj.exogenous.shock_horizon);
        load_ssfuncs=isempty(obj.current_solution_state);
        if ~resolve_it && ~isfield(obj.current_solution_state,'solve_function_mode')
            % maybe I should have refresh do this? and possibly
            % redifferentiate the whole system?
            obj.current_solution_state.solve_function_mode=obj.options.solve_function_mode;
        end
        if resolve_it
            obj.current_solution_state=fill_solve_state_info();
        else
            new_state=fill_solve_state_info();
            try
                load_ssfuncs=load_ssfuncs||...
                    ~strcmp(new_state.derivatives_type,obj.current_solution_state.derivatives_type)||...
                    ~strcmp(new_state.solve_function_mode,obj.current_solution_state.solve_function_mode);
            catch
                load_ssfuncs=true;
            end
            resolve_it= ~isequal(new_state,obj.current_solution_state);
            if resolve_it
                obj.current_solution_state=new_state;
            end
        end
        % steady state functions (just for output)
        %-----------------------------------------
        if load_ssfuncs
            obj.steady_state_funcs=recreate_steady_state_functions(obj);
        end
        
        function new_state=fill_solve_state_info()
            new_state=struct('horizon',horizon,...
                'solution_algo',obj.options.solver,...
                'solve_order',solve_order,...
                'params',params,...
                'derivatives_type',obj.options.solve_derivatives_type,...
                'solve_function_mode',obj.options.solve_function_mode...
                );
        end
    end
    function retcode=solve_zeroth_order()
        retcode=0;
        if resolve_it
            if isempty(obj.solution)||~obj.estimation_under_way
                obj.solution=struct();%dsge.initialize_solution_or_structure('solution',h);
                obj.solution.H=cell(1,h);
            end
            % check whether I am not changing some data types in here to
            % explain why obj on the left-hand side is updated so slowly. I
            % could try different things :
            % 1- only output the solution and the updated parameters...
            % 2- put most of those things are sub-functions or nested
            % functions.
            [obj,structural_matrices,retcode]=compute_steady_state(obj);
            if ~retcode
                % measurement errors
                %-------------------
                if ~retcode
                    measure_flag=~isempty(obj.measurement_errors_restrictions);
                    if measure_flag
                        Restrictions=obj.measurement_errors_restrictions;
                        tmp=zeros(obj.observables.number(1),1);
                        for s0=1:h
                            tmp(Restrictions(:,1))=params(Restrictions(:,2),s0).^2;
                            obj.solution.H{s0}=diag(tmp);
                        end
                    end
                end
            end
        end
        % spit out the forms to be used for the computation of derivatives
        %-----------------------------------------------------------------
        if ~retcode
            ys=zeros(nind,h);
            ss=zeros(endo_nbr,h);
            def=obj.solution.definitions;
            % in case of optimal policy, we are not interested in the whole
            % vector of sstates. We need to locate what we need
            original=obj.endogenous.is_original;
            for s0=1:h
                for s1=1:h
                    if s0==1
                        ss(:,s1)=obj.solution.ss{s1}(original);
                        ys(:,s1)=ss(indices,s1);
                        % y needs to be modified for the variables that have a
                        % nonzero balanced-growth path
                        if ~obj.is_stationary_model
                            if s1==1
                                [bgp_coefs,change_loc]=balanced_growth_path_powers();
                            end
                            ys(change_loc,s1)=ys(change_loc,s1).*obj.solution.bgp{s1}(indices(change_loc)).^bgp_coefs;
                        end
                    end
                end
            end
        end
        function [bgp_coefs,change_loc]=balanced_growth_path_powers()
            bgp_1=obj.solution.bgp{s1};
            bgp_vars=find(abs(bgp_1)>1e-3); % very low threshold...
            c_leads=zeros(size(the_leads)); c_leads(ismember(the_leads,bgp_vars))=1;
            c_current=zeros(size(the_current)); %c_current(ismember(the_current,bgp_vars))=0;
            c_lags=zeros(size(the_lags)); c_lags(ismember(the_lags,bgp_vars))=-1;
            cc=[c_leads(:);c_current(:);c_lags(:)];
            change_loc=cc~=0;
            bgp_coefs=cc(change_loc);
        end
    end

    function retcode=log_expansion()
        retcode=0;
        if ischar(solve_log_approx_vars)
            solve_log_approx_vars=cellstr(solve_log_approx_vars);
        end
        log_vars=false(1,obj.endogenous.number(end));
        log_vars(locate_variables(solve_log_approx_vars,obj.endogenous.name))=true;
        % cannot be some original log_var
        %---------------------------------
        double_log=log_vars & obj.endogenous.is_log_var;
        if any(double_log)
            disp(obj.endogenous.name(double_log))
            error(['The variables above were already in log-form. ',...
                'A further log-expansion cannot be taken on them'])
        end
        % cannot be observable
        %----------------------
        if obj.observables.number(1)
            obs_id=real(obj.observables.state_id);
            log_obs=log_vars(obs_id);
            if any(log_obs)
                disp(obj.endogenous.name(log_obs))
                error('The variables above are observed. They cannot be log-expanded')
            end
        end
        tt=obj.locations.after_solve.t;
        pb_pos=[tt.p,tt.b];
        npb=numel(pb_pos);
        order_var=obj.order_var.after_solve;
        nstates=size(T.Tz{1},2);
        ss_state_list=ones(1,nstates);
        for ireg_=1:h
            ss__=obj.solution.ss{ireg_}(:).';
            obj.solution.ss{ireg_}(log_vars)=0;
            % cannot have a zero steady state
            %---------------------------------
            if any(abs(ss__(log_vars))<obj.options.fix_point_TolFun)
                retcode=27;
            end
            if retcode
                return
            end
            ss__=ss__(order_var);
            ss_state_list(1:npb)=ss__(pb_pos);
            zkz=1;
            Tz_='T';
            for io=1:obj.options.solve_order
                zkz=kron(zkz,ss_state_list);
                Tz_=[Tz_,'z'];
                T.(Tz_){ireg_}=bsxfun(@times,T.(Tz_){ireg_},zkz);
                % we need to full this because the various multiplications
                % transform to sparse and create problems with reshape
                % later on.
                T.(Tz_){ireg_}=full(bsxfun(@rdivide,T.(Tz_){ireg_},ss__(:)));
            end
        end
    end
end

function [the_leads,the_current,the_lags,indices,nind,endo_nbr]=create_indices(lead_lag_incidence)
endo_nbr=size(lead_lag_incidence,1);
the_leads=find(lead_lag_incidence(:,1)>0);
the_current=(1:endo_nbr)';
the_lags=find(lead_lag_incidence(:,3)>0);
indices=[the_leads;the_current;the_lags];
nind=numel(indices);
end

function ssfuncs=recreate_steady_state_functions(obj)
% initialize this here
ssfuncs=struct();

symbolic_derivatives=strcmp(obj.options.solve_derivatives_type,'symbolic');
ssfuncs.static=obj.routines.static;
ssfuncs.static_bgp=obj.routines.static_bgp;
if symbolic_derivatives
    ssfuncs.jac_static=obj.routines.static_derivatives;
    ssfuncs.jac_bgp=obj.routines.static_bgp_derivatives;
else
    solve_order=1;
    ssfuncs.jac_static=compute_automatic_derivatives(obj.routines.symbolic.static,solve_order);
    ssfuncs.jac_bgp=compute_automatic_derivatives(obj.routines.symbolic.static_bgp,solve_order);
end
end

function func=compute_automatic_derivatives(derivatives,solve_order)

func=@engine;

    function [D01,retcode]=engine(varargin)
        D01=utils.code.evaluate_automatic_derivatives(derivatives,solve_order,varargin{:});
        good=all(cellfun(@(x)utils.error.valid(x),D01));
        retcode=0;
        D01=D01{1};
        if ~good
            retcode=2; % nans in jacobian
        end
    end
end