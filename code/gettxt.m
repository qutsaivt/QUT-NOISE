% Function to get a list of text from a text file and places it in an array of cells
%
% Usage:-
%
%     	lst = gettxt(file)


function lst = gettxt(file)

% Open text file
fp = fopen(file,'rt');

% Define cell array
lst = {};
pos = 1;

% Loop until EOF
while 1
   [str,count] = fscanf(fp,'%s',1);
   if count == 1
      lst{pos} = str;
      pos = pos + 1;
   else
      break;
   end   
end

% Finally close file
fclose(fp);
