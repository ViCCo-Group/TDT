function warningv(msg_id,msg)

% This function makes sure that a warning is only printed once at each
% level of execution. For example, in feature selection a warning message
% should only be printed once. It is similar to warning.m, but does not
% allow input similar to fprintf as would be possible in warning.m .

global reports %#ok

callers = dbstack;
callers_name = char(callers.name);
callers_name(:,end+1) = ' '; % for making search for 'decoding' unique

stop_ind = strmatch('decoding ',callers_name);

str = 'reports'; % define level at which message should be deactivated
for i = stop_ind:-1:2
    str = [str '.' deblank(callers_name(i,:))];
end

ind = findstr(msg_id,':');
if ~isempty(ind)
    msg_id_short = msg_id(ind+1:end); % remove function location (already provided by dbstack)
else
    msg_id_short = msg_id;
end
str = [str '.' msg_id_short];

% The use of eval is not very pretty, anyone has a better idea?

try % try adding one to the field
    eval([str '=' str '+1;'])
    eval(['if ' str ' == 2, fprintf(''Future warnings at same level switched off. Number of warnings stored in cfg.\n''), end'])
catch %#ok if not possible, create field and plot warning message
    eval([str '= 1;']);
    warning(msg_id,msg)
end




