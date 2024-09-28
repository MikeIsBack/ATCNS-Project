%% FALSE ALARM COMPUTATION - ONLY AUTHED SIGNALS

clear;
clc;

N = 50; % Number of simulation rounds
% Over class of Bluetooth, we have the following:
% Class 1 = 20 dB in power and expected distance of 100 m.
% Here, we establish an avg range in which to send 10 dB of 50 m.,
% according to Bluetooth class 1

% Definition of SNR
SNR_min = 10; % Minimum SNR in dB
SNR_max = 30; % Maximum SNR in dB
SNR_step = -1; % SNR step size
SNR = SNR_max:SNR_step:SNR_min;
power = 10.^(SNR/10);

% Define signal parameters
signal_length = 100; % Length of the signals
% Determine min and max power (over range of Bluetooth and its bounds)
% Ideally, between avg value (-20; 20) is for all Bluetooth
power_X = -10; % Power for bit 0
power_Y = 10; % Power for bit 1

std_th_minus = power_X;
std_th_plus = power_Y;

% Fixed threshold for authentication signal: assuming this is lower than
% the original signal, since auth + data gives received signal
std_th_auth_plus = +5;
std_th_auth_minus = -5;

% Initialize signals
data_signal = zeros(1, signal_length);
authentication_signal = zeros(1, signal_length);

% Define simulation parameters
max_distance = 50; % Maximum distance in meters

% Initialize data-auth-signal mixed
binary_data = [];
binary_auth=[];
S = zeros(1, signal_length);

% Assuming center is 0 (given the signal is -10 and 10)
center = 0;

% Initialize wrong bits
wrong_auth_bits = 0;
wrong_data_bits = 0;

% Allowed wrong bits
n_allowed_bits_auth = 3; % Given average values of error, this was found to be an average good value

% BER analysis vectors
BER_data_vec = zeros(max_distance, length(SNR));
BER_auth_vec = zeros(max_distance, length(SNR));

% Received data and authentication bits
received_data = zeros(1, signal_length);
received_auth = zeros(1, signal_length);

% False alarm counter
false_alarm = 0;
FA_matrix = zeros(max_distance, length(SNR));

for j = 1:max_distance
    for k = 1:length(SNR)
        for index = 1:N
            % Generate auth and data signals and mixing 
            binary_data = randi([0, 1], 1, signal_length); 
            binary_auth = randi([0, 1], 1, signal_length);
            for in = 1:signal_length
                if binary_data(in) == 1
                    data_signal(in) = power_Y;
                else
                    data_signal(in) = power_X;
                end
                if binary_auth(in) == 1
                    authentication_signal(in) = std_th_auth_plus;
                else
                    authentication_signal(in) = std_th_auth_minus;
                end
                S(in) = data_signal(in) + authentication_signal(in);
            end

            %% TRANSMISSION OF ENTIRE SIGNAL

            % Signal at receiver
            received_signal = awgn(S, SNR(k));
            
            % Zeroing bits at every iteration
            wrong_data_bits = 0;
            wrong_auth_bits = 0;
           
            %% FIXED THRESHOLDS DECODING
            
            % Loop through each bit in the received signal
            for i = 1:signal_length
                % Decode the received signal with fixed thresholds  
                % First, we decode the data and see the wrong bits for BER
                if received_signal(i) >= center 
                    received_data(i) = 1;
                    % Epsilon allows to retrieve error percentage - this value
                    % is strictly dependent on the min/max value of auth
                    % signal, given it's the smaller signal
                    if round(received_signal(i)) == std_th_auth_plus
                        received_auth(i) = 0;                
                    else
                        received_auth(i) = 1;                
                    end
                elseif received_signal(i) < center
                    received_data(i) = 0;
                    if round(received_signal(i)) == std_th_auth_minus
                        received_auth(i) = 1;                
                    else
                        received_auth(i) = 0;                
                    end
                end
            end
    
            % Checking the wrong bits in both signals (Hamming distance)
            for i = 1:signal_length
                if received_data(i) ~= binary_data(i) 
                    wrong_data_bits = wrong_data_bits + 1;
                end
                if received_auth(i) ~= binary_auth(i) 
                    wrong_auth_bits = wrong_auth_bits + 1;
                end
            end

            % disp("FIXED DECODING: " + wrong_auth_bits)

            % Calculate BER for the current iteration
            BER_data = wrong_data_bits / signal_length;
            BER_auth = wrong_auth_bits / signal_length;

            wrong_auth_bits = 0;
            wrong_data_bits = 0;
            
            if wrong_auth_bits > n_allowed_bits_auth
                %% VARIABLE THRESHOLDS DEFINITION
                
                % First, there is the variable thresholds settings
                
                % Assuming received_signal is already defined as a vector of values
                HH = max(received_signal);    % high high
                LL = min(received_signal);    % low low
                MH = HH/2;  % medium high
                ML = LL/2;  % medium low
                
                % Definition of nearest ML/LM variables
                % made to actually refine the finding of the 4 power values for
                % dynamic thresholding decoding
                nearest_MH = 0;
                nearest_ML = 0;
                
                for i = 1:length(received_signal)
                    if received_signal(i) > center % assuming is 0 (in out case)
                        if nearest_MH == 0
                            nearest_MH = received_signal(i);  % first value
                        elseif abs(received_signal(i) - MH) < abs(nearest_MH - MH)
                            % MH is the theoretical midhigh point, then refined
                            % with the actual value when it is found between
                            % the actual high interval and the highest value
                            nearest_MH = received_signal(i);
                        end
                    else
                        if nearest_ML == 0
                            nearest_ML = received_signal(i);  % first value
                        elseif abs(received_signal(i) - ML) < abs(nearest_ML - ML)
                            nearest_ML = received_signal(i);
                            % ML is the theoretical midlow point, then refined
                            % with the actual value when it is found between
                            % the actual low interval and the lowest value
                        end
                    end
                end
                    
                % Second, there is the actual decoding (names matching the drawing
                % in page 2 of 4 of Alessandro's notes of 24-04)
                
                T1 = HH;
                T2 = nearest_MH;
                T3 = nearest_ML;
                T4 = LL;

                %% VARIABLE THRESHOLDS DECODING
    
                % Loop through each bit in the received signal
                for i = 1:signal_length
                    % Received data already avaiable at this stage,
                    % theoretically:
    
                    % % Decode the received signal with fixed thresholds  
                    % % First, we decode the data and see the wrong bits for BER
                    % if received_signal(i) >= center 
                    %     received_data(i) = 1;
                    % elseif received_signal(i) < center
                    %     received_data(i) = 0;
                    % end
    
                    % First the 0 encoding (obtain more real values)
                    if received_data(i) == 1 && received_signal(i) < T1
                        received_auth(i) = 1;
                    end
                    if received_data(i) == 1 && received_signal(i) <= T2
                        received_auth(i) = 0;
                    end
                    if received_data(i) == 0 && received_signal(i) > T4
                        received_auth(i) = 0;
                    end
                    if received_data(i) == 0 && received_signal(i) >= T3
                        received_auth(i) = 1;
                    end
    
                    % Theoretical perfect decoding
    
                    % if received_data(i) == 1 && received_signal(i) < T1
                    %     received_auth(i) = 1;
                    % end
                    % if received_data(i) == 1 && received_signal(i) < T2
                    %     received_auth(i) = 0;
                    % end
                    % if received_data(i) == 0 && received_signal(i) > T4
                    %     received_auth(i) = 0;
                    % end
                    % if received_data(i) == 0 && received_signal(i) > T3
                    %     received_auth(i) = 1;
                    % end
                end
    
                % Checking the wrong bits in both signals (Hamming distance)
                for i = 1:signal_length
                    if received_data(i) ~= binary_data(i) 
                        wrong_data_bits = wrong_data_bits + 1;
                    end
                    if received_auth(i) ~= binary_auth(i) 
                        wrong_auth_bits = wrong_auth_bits + 1;
                    end
                end

                % disp("VARIABLE DECODING: " + wrong_auth_bits)
    
                % Calculate BER for the current iteration considering 
                % the new variable thresholds decoding
                BER_data = wrong_data_bits / signal_length;
                BER_auth = wrong_auth_bits / signal_length;
    
            end

            % Store BER values in the vectors
            BER_data_vec(j, k) = BER_data;
            BER_auth_vec(j, k) = BER_auth;

            % Check again if wrong bits are over the threshold
            % and see if message could be considered wrong
            % so increment false alarm

            if wrong_auth_bits > 0
                false_alarm = false_alarm + 1;
            end

            % Assuming encoding is without effect of noise, the decoding is
            % very performing from a practical point of view; so, as
            % condition, we impose the the wrong bits to be dependent on
            % the encoding, so to be just greater than 0

            % After loop FA(d, SNR) = false_alarm / number_messages
            % (in our case N)

        end
        FA_matrix(j, k) = false_alarm;
        false_alarm = 0;
    end
end