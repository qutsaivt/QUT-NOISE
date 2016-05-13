function [data,fs] = readaudio(file)

% READAUDIO attempts to load audio data from an audio file

try
  [data, fs] = readsph(file);
catch err
  [data, fs] = audioread(file);
end