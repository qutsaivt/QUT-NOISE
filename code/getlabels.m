function [labels] = getlabels(labelfilename)

labels = [];

fid = fopen(labelfilename);
while ~feof(fid)
  line = fgetl(fid);
  [start,line] = strtok(line);
  [finish,labeltext] = strtok(line);
  labeltext = strtrim(labeltext);
  start=str2num(start);
  finish=str2num(finish);

  label = [];
  label.time = [start finish];
  label.text = labeltext;

  labels = [labels; label];
end
fclose(fid);
