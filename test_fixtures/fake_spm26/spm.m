function output = spm(command)

if strcmpi(command, 'ver')
    output = 'SPM26';
else
    error('Fake SPM26 fixture only implements spm(''ver'').')
end
