function writelabels(labels,labelfile)

fid=fopen(labelfile,'wt');

for i = 1:length(labels)
  fprintf(fid,'%g %g %s\n',labels(i).time(1), ...
	  labels(i).time(2), labels(i).text);
end

fclose(fid);
