function warningv(msg_id,msg)

% This function makes sure that a warning is only printed once at each
% level of execution. For example, in feature selection a warning message
% should only be printed once. It is similar to warning.m, but does not
% allow input similar to fprintf as would be possible in warning.m .
%
% The input is similar to warning (see 'help warning'):
%   msg_id: Message identifier
%   msg: The actual warning message
% No additional sprintf-like input is allowed!


global reports %#ok

callers = dbstack;
callers_name = {callers(2:end).name}; % remove warningv from list
stop_ind = find(strcmp('decoding',callers_name)); % stop when top function 'decoding.m' has been reached
if isempty(stop_ind)
    stop_ind = length(callers_name); % when decoding was not included in the call, include all levels
end

field_id = 'reports.warning'; % define level at which message should be deactivated
for i = stop_ind:-1:1
    field_id = [field_id '.' callers_name{i}];
end

ind = findstr(msg_id,':');
if ~isempty(ind)
    msg_id_short = msg_id(ind+1:end); % remove function location (already provided by dbstack)
else
    msg_id_short = msg_id;
end
field_id = [field_id '.' msg_id_short];

% TODO: The use of eval is not very elegant, but it is fast.

try % try adding one to the field
    eval([field_id '=' field_id '+1;'])
    eval(['if ' field_id ' == 2, fprintf(''Future warnings at same level switched off. Number of warnings stored in cfg.\n''), end'])
catch %#ok if not possible, create field and plot warning message
    eval([field_id '= 1;']);
    warning(msg_id,msg)
end




