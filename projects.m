%PROJECTS Project manager for MATLAB
%   PROJECTS(cmd, projectName) manages current working directory and files
%   that are opened in MATLAB editor (but not the workspace).
%   Available commands are:
%     'list', 'show', 'save', 'load', 'close', 'rename', 'delete', 'active'
%
%   PROJECTS or
%   PROJECTS('list') shows all stored projects. Arrow marks active project.
%
%   PROJECTS('active') returns the name of the active project
%
%   PROJECTS('show') shows information about the current project
%   PROJECTS('show', project_name) shows information about the project
%
%   PROJECTS('close') closes all opened files
%
%   PROJECTS('save') saves current working directory and editor state under
%   the active project
%   PROJECTS('save', projectName) saves current working directory and
%   editor state under the specified project name
%
%   PROJECTS('load') restores the project "default"
%   PROJECTS('load', projectName) restores the project with specified name
%
%   PROJECTS('open') is synonym for PROJECTS('load')
%
%   PROJECTS('rename', newName) renames the active project
%   PROJECTS('rename', projectName, newName) renames the project
%
%   PROJECTS('delete') deletes the active project
%   PROJECTS('delete', projectName) deletes the project with specified name
%
%   Examples:
%       projects list
%       projects save myProject
%       projects close
%       projects load default
%       projects rename myProject myLibrary
%
%   All projects are stored in the %userpath%/projects.mat. This file with
%   empty "default" project is created at the first run of the script. If
%   %userpath% is empty, the script will execute userpath('reset').
%
%   First project always has name "default"

% Copyright 2012-2013, Vladimir Filimonov (ETH Zurich).
% $Date: 12-May-2012 $

% Extended and cleaned up a bit by Rody Oldenhuis (oldenhuis@gmail.com)
% 16 Oct 2018
%
% If you find this work useful, please consider a donation:
% https://www.paypal.me/RodyO/3.5

function varargout = projects(cmd, varargin)
    
    persistent projectsList_
    persistent activeProject_
    
    if verLessThan('matlab','7.12')
        error([mfilename() ':matlab_too_old'], [...
              'Projects: MATLAB versions older than R2011a (7.12) are ',...
              'not supported']);
    end
    
    if isempty(userpath())
        userpath('reset'); end
    
    fpath = userpath();
    if strcmp(fpath(end),';')
        fpath = fpath(1:(end-1)); end
    fpath = fullfile(fpath, 'projects.mat');
     
    % First run ever
    if ~exist(fpath,'file')
        projectsList = struct('ProjectName', 'default',...
                              'OpenedFiles',  {{}},...
                              'ActiveDir'  ,  userpath());
        activeProject = 1;
        save_projects();        
    end
    
    % First call this session
    if isempty(projectsList_)
        D = load(fpath, 'projectsList', 'activeProject');
        projectsList_  = D.projectsList;
        activeProject_ = D.activeProject;
    end
    
    projectsList  = projectsList_;
    activeProject = activeProject_; 
    
    % Some useful variables
    allNames       = {projectsList.ProjectName};
    currentProject = projectsList(activeProject).ProjectName;
    
    % Default command: list all projects
    if nargin==0
        cmd = 'list'; end
    
    % Pokemon error handler
    try     
        
        switch lower(cmd)

            case 'new'
                
                varargout = projects('close');
                edit();
                
                prjname = input('Input new project name: ', 's');
                projects('save', prjname);

            case 'close'
                
                if projects('modified')
                    projects('save'); end

                varargout = {true};
                openDocuments = matlab.desktop.editor.getAll;
                openDocuments.close;

                %load(fpath)
                activeProject = 1;                
                save_projects();
            
            case 'list'
                
                disp('List of available projects:')                
                varargout = allNames;
                
                % Handle subprojects
                projectNum  = 1:numel(projectsList);                
                subProj     = regexp(allNames, ':', 'split', 'once');
                subproj_ind = cellfun('prodofsize', subProj) > 1;
                
                % With subprojects: re-order
                if any(subproj_ind)
                    
                    % Print projects without further structure
                    noProj    = allNames(~subproj_ind);
                    noProjNum = projectNum(~subproj_ind);
                    
                    tgt = 1;
                    if any(noProjNum==activeProject)
                        tgt = 2; end
                    fprintf(tgt, '\n%s:\n', 'NO PARENT PROJECT:');
                    
                    print_project_list(noProjNum,...
                                       noProj,...
                                       activeProject);
                                                                      
                    % Print parent/child projects
                    projectNames  = cellfun(@(x)x{1}, subProj(subproj_ind),...
                                            'UniformOutput', false);                                            
                    uProjectNames = unique(projectNames);                     
                    [~,projInd]   = ismember(projectNames, uProjectNames);
                        
                    projectInds = zeros(size(allNames));
                    projectInds(subproj_ind) = projInd;
                    
                    for ii = 1:numel(uProjectNames)
                        
                        subProjectInds = projectInds==ii;
                        projNum = projectNum(subProjectInds);
                        proj    = allNames(subProjectInds);
                        
                        tgt = 1;
                        if any(projNum==activeProject)
                            tgt = 2; end                        
                        fprintf(tgt, '\n%s:\n',...
                                upper(uProjectNames{ii}));
                                                
                        print_project_list(projNum,...
                                           proj,...
                                           activeProject);
                    end
                                                              
                % No subprojects: just produce simple list                         
                else  
                    print_project_list(projectNum,...
                                       allNames,...
                                       activeProject);
                end                
                
            case {'show', 'info'}
                
                if nargin==1
                    ind = activeProject;
                else
                    prjname = varargin{1};                
                    check_project_name(prjname, projectsList);
                end

                switch nargout
                    case 0
                        disp(projectsList(ind));
                    case 1
                        varargout{1} = projectsList(activeProject);                
                    otherwise
                        error([mfilename() ':nargcount'],...
                              'Show command only returns 1 string.');
                end
            
            case 'active'
                
                switch (nargout)
                    case 1
                        varargout{1} = currentProject;
                    case 0
                        fprintf(1, 'Active project is "%s"\n',...
                                currentProject);
                    otherwise
                        error([mfilename() ':nargcount'],...
                              'Querying the active project only returns 1 string.');
                end
            
            case 'save'

                if nargin==1
                    ind     = activeProject;
                    prjname = currentProject;
                else
                    prjname = varargin{1};
                    ind     = find(strcmpi(prjname, allNames), 1);
                    if isempty(ind)
                        ind = length(projectsList) + 1; end
                end

                projectsList(ind).ProjectName = prjname;
                projectsList(ind).OpenedFiles = get_all_open_documents();
                projectsList(ind).ActiveDir   = pwd;

                activeProject = ind;                 
                save_projects();
                update_tab_completion({projectsList.ProjectName});
                fprintf(1,'Project "%s" saved\n', prjname);
            
            case {'open', 'load'}

                % Basic checks
                if nargin==1
                    disp('Loading "default" project...')
                    prjname = 'default';
                else
                    prjname = varargin{1};
                end
                
                ind       = check_project_name(prjname, projectsList);
                thedir    = projectsList(ind).ActiveDir;
                filenames = projectsList(ind).OpenedFiles;
                
                if ind == activeProject
                    
                    fprintf(1, 'Project "%s" was already active; checking...', ...
                            projectsList(ind).ProjectName);
                        
                    % Check if everything is still the same
                    filesOK = all(ismember(filenames,...
                                           get_all_open_documents()));
                    dirOK = isequal(thedir, pwd);
                    
                    if filesOK && dirOK                        
                        fprintf(1, 'all OK\n');
                        return;
                    end
                    
                    fprintf(1, 'restoring...\n');                    
                    
                else                    
                    projects('close');
                    %load(fpath);
                end

                % Load up the new project's open files
                for ii = 1:length(filenames)
                    if exist(filenames{ii}, 'file')
                        matlab.desktop.editor.openDocument(filenames{ii});
                    else
                        warning('File "%s" was not found',...
                                filenames{ii});
                    end
                end

                % Set the new project's PWD                
                try
                    evalin('base', ['cd(''' thedir ''');']);
                catch
                    warning([mfilename() ':activedir_removed'],...
                            'Directory "%s" does not exist',...
                            thedir);
                end

                % Finalize everything
                activeProject = ind;
                save_projects();
                update_current_project(prjname);
                fprintf(1, 'Project "%s" restored\n', prjname);
            
            case 'rename'

                switch nargin
                    case 1
                        error([mfilename() ':project_not_specified'],...
                              'Project name was not specified');
                    case 2
                        prjold = currentProject;
                        prjnew = varargin{1};
                    case 3
                        prjold = varargin{1};
                        prjnew = varargin{2};
                    otherwise
                        error([mfilename() ':argc'],...
                              'Too many input arguments.');
                end

                ind = check_project_name(prjold, projectsList);

                projectsList(ind).ProjectName = prjnew;
                save_projects();
                update_tab_completion({projectsList.ProjectName});
                fprintf(1, 'Project "%s" was renamed to "%s"\n',...
                        prjold, prjnew);
            
            case 'delete'

                if nargin==1
                    ind     = activeProject;
                    new_prj = 'default';
                else
                    prjname = varargin{1};
                    ind     = find(strcmpi(prjname, allNames), 1);
                    if isempty(ind)
                        error([mfilename() ':project_not_found'],...
                              'Required project was not found')
                    end
                    if ind == activeProject
                        new_prj = 'default';
                    else
                        new_prj = currentProject;
                    end
                end

                assert(ind ~= 1,...
                       [mfilename() ':cannot_remove_default'],...
                       'Cannot delete "default" project.');

                prjname = projectsList(ind).ProjectName;
                projectsList(ind) = [];
                activeProject = find(strcmpi(new_prj, {projectsList.ProjectName}), 1);

                save_projects();
                update_tab_completion({projectsList.ProjectName});
                
                fprintf(1, 'Project "%s" deleted\n', prjname);
                if activeProject==1
                    disp('Current project changed to "default"'); end
            
            case 'modified'

                fn_saved  = projectsList(activeProject).OpenedFiles;            
                fn_opened = get_all_open_documents();

                varargout = {false};
                if length(fn_saved) ~= length(fn_opened)
                    varargout = {true};
                else
                    for ii=1:length(fn_saved)
                        if ~strcmpi(fn_saved{ii},fn_opened{ii})
                            varargout = {true}; end
                    end
                end

                if nargout==0                    
                    yn = '';
                    if varargout{1}
                        yn = ' not'; end                    
                    fprintf(1, 'Project "%s" was%s modified',...
                            currentProject,...
                            yn);
                end
            
            otherwise

                % If command is a valid project, save the current project 
                % and switch to the requested project                
                projectmatch = strcmp(cmd, allNames);
                if any(projectmatch)
                    activeproj = projects('active');
                    projects('save', activeproj);
                    if ~strcmpi(activeproj, cmd) % (but not if it's already current)
                        projects('load', allNames{projectmatch}); end
                else
                    error([mfilename() ':unknown_command'],...
                          'Projects: unknown command.');
                end

        end
        
    % End pokemon error handler    
    catch ME                        
        rethrow(ME);
    end
    
    if nargout==0
        varargout = {}; end
    
    % Oft-repeated phrase
    function save_projects()
        projectsList_  = projectsList;
        activeProject_ = activeProject;
        save(fpath, 'projectsList', 'activeProject');
    end
    
end

% Helper function: check given project name and return ind to it    
function ind = check_project_name(prjname, projectsList)
    ind = find(strcmpi(prjname, {projectsList.ProjectName}), 1);
    assert(~isempty(ind),...
           [mfilename() ':unknown_project'],...
           'Unknown project name.');
end

% Print numbered projects list, with colored indication of active project
function print_project_list(indices, names, activeProject)
    for ii = 1:numel(names)
        str = '   ';
        tgt = 1;
        if indices(ii) == activeProject
            str = '-> '; tgt = 2; end
        fprintf(tgt, '%s%2d: %s\n',...
                str, indices(ii), names{ii});
    end
end

% Get list of documents currently open in the editor
function filenames = get_all_open_documents()
    open_docs = matlab.desktop.editor.getAll;
    filenames = {open_docs.Filename};
end

% R2016b+ uses JSON to do tab-completion
function update_tab_completion(projectlist)
    
    fixed = {'close' 'list' 'active' 'rename' 'delete' 'load' 'save'};
    fname = fullfile(fileparts(mfilename('fullpath')), 'functionSignatures.json');
        
    if exist(fname,'file')~=2
        warning([mfilename() ':json_not_found'], [...
                'Tab-completion configuration (JSON) not found. Please ',...
                'check out at least the tab-completion template before ',...
                'using the projects() function.']);
        return; 
    end
    
    % Get JSON
    fid = fopen(fname, 'r');
    OC1 = onCleanup(@() any(fopen('all')==fid) && fclose(fid));
        json = textscan(fid, '%s', 'Delimiter','', 'Whitespace','');
    fclose(fid);
    json = json{1}; 
    
    % Convert to MATLAB struct
    data = jsondecode([json{:}]);
    
    % Insert all current projects
    joinup = @(cstr) [sprintf('''%s'' ', cstr{1:end-1}) '''' cstr{end} ''''];
    data.(mfilename).inputs(1).type = ['choices={' joinup(fixed) ' ' joinup(projectlist) '}'];
    data.(mfilename).inputs(2).type = ['choices={' joinup(projectlist) '}'];
    
    % Convert back the struct to JSON
    json = cellstr(jsonencode(data));
    
    % Write the updated JSON to file    
    fid  = fopen(fname, 'w');
    OC2  = onCleanup(@() any(fopen('all')==fid) && fclose(fid));
        cellfun(@(x) fprintf(fid, '%s\n', x), json);
    fclose(fid);
    
end


function update_current_project(current_project)
    return 
    
    fname = fullfile(fileparts(mfilename('fullpath')),...
                     'current_project.txt');
                 
	fid = fopen(fname,'w');
    OC  = onCleanup(@() any(fopen('all')==fid) && fclose(fid));    
    fprintf(fid, '%s', current_project);    
    fclose(fid);
    
end
