function writestructcsv(struct,csvfile,showfieldnames)

if ~exist('showfieldnames')
  showfieldnames=0;
end

fid=fopen(csvfile,'wt');

fields=fieldnames(struct);
if showfieldnames ~= 0
  fprintf(fid, '# ');
  fprintf(fid, '%s, ', fields{:});
  fprintf(fid, '\n');
end
for i = 1:length(fields)
  value=struct.(fields{i});
  if isnumeric(value)
    fprintf(fid, '%g, ', value);
  elseif ischar(value)
    fprintf(fid, '%s, ', value);
  else
    error('Only numeric and string data is supported.');
  end
end
fprintf(fid, '\n');

fclose(fid);
