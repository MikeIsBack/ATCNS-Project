%% MISS DETECTION COMPUTATION - ONLY NON-AUTHED SIGNALS

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
n_allowed_bits_auth = 3;

% BER analysis vectors
BER_data_vec = zeros(max_distance, length(SNR));
BER_auth_vec = zeros(max_distance, length(SNR));

% Received data and authentication bits
received_data = zeros(1, signal_length);
received_auth = zeros(1, signal_length);

% False alarm counter
missed_detection = 0;
MD_matrix = zeros(max_distance, length(SNR));

% Decoded signals for MITM
MITM_decoded_auth = zeros(1, signal_length);
MITM_decoded_data = zeros(1, signal_length);

% Actual signals to be sent from MITM
MITM_auth_signal = zeros(1, signal_length);
MITM_data_signal = zeros(1, signal_length);

for j = 1:max_distance
    for k = 1:length(SNR)
        for index = 1:N
            %% ORIGINAL MESSAGE DEFINITION AND TRANSMISSION 

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

            % SENT SIGNAL
            received_signal = awgn(S, SNR(k));

            %% MAN IN THE MIDDLE SNIFFING
            
            MITM_received_signal = received_signal;
            
            % Find the maximum and minimum peaks of the received signal
            MITM_max_peak = max(MITM_received_signal);
            MITM_min_peak = min(MITM_received_signal);
            
            % Calculate the midpoint between the maximum and minimum peaks
            MITM_midpoint = (MITM_max_peak + MITM_min_peak) / 2;
            
            % Set the power thresholds based on the midpoint
            MITM_power_threshold_high = MITM_midpoint + (MITM_max_peak - MITM_midpoint) * 0.5;
            
            % high power threshold is set to a value halfway between the midpoint 
            % and the maximum peak. This assumes that values above this threshold 
            % are likely to represent a binary '1'.

            MITM_power_threshold_low = MITM_midpoint - (MITM_midpoint - MITM_min_peak) * 0.5;
            
            % low power threshold is set to a value halfway between the midpoint and the minimum peak.
            % This assumes that values below this threshold are likely 
            % to represent a binary '0'.

            % MITM's decoding attempt

            % Tries variable decoding using a defined center (midpoint)

            for i = 1:signal_length
                if received_signal(i) >= MITM_midpoint 
                    MITM_decoded_data(i) = 1;
                    if received_signal(i) < MITM_power_threshold_high
                        MITM_decoded_auth(i) = 0;                
                    else
                        MITM_decoded_auth(i) = 1;                
                    end
                elseif received_signal(i) < MITM_midpoint
                    MITM_decoded_data(i) = 0;
                    if received_signal(i) > MITM_power_threshold_low
                        MITM_decoded_auth(i) = 1;                
                    else
                        MITM_decoded_auth(i) = 0;                
                    end
                end
            end
           
            % Transmit the MITM's decoded signal with power values
            MITM_transmitted_signal = zeros(1, signal_length);

            % Determining power values in order to mix data and auth

            % Assuming the MITM has knowledge of the channel and the auth
            % signal conditiones the power of the actual data signal so to
            % have smaller key thresholds conditioning data thresholds
            % = using peaks of data and then simply calculating lesser data
            % thresholds

            power_data_plus = (MITM_max_peak / 2) + 1; 
            % knowing that data bits are transmitted with a high power
            % compared to higher ones, we compute as transmitted power for
            % data bits the maximum peak of power divided by 2 plus 1, in
            % order to have a higher power for data transmission
            power_data_minus = (MITM_min_peak / 2) + 1;

            power_auth_plus = MITM_max_peak - power_data_plus;
            power_auth_minus = MITM_min_peak + power_data_minus;
 
            for i = 1:signal_length
                if MITM_decoded_auth(i) == 1
                    MITM_auth_signal(i) = power_auth_plus;
                else
                    MITM_auth_signal(i) = power_auth_minus;
                end
                if MITM_decoded_data(i) == 1
                    MITM_data_signal(i) = power_data_plus;
                else
                    MITM_data_signal(i) = power_data_minus;
                end
                MITM_transmitted_signal(i) = MITM_auth_signal(i) + MITM_data_signal(i);
            end
            
            % Assign the MITM's transmitted signal to the received_signal variable
            received_signal = MITM_transmitted_signal;

            %% RECEIVER DECODING

            % Zeroing bits at every iteration
            wrong_data_bits = 0;
            wrong_auth_bits = 0;
           
            % FIXED THRESHOLDS DECODING
            
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

            if wrong_auth_bits > n_allowed_bits_auth
                % VARIABLE THRESHOLDS DEFINITION
                
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

                % VARIABLE THRESHOLDS DECODING
    
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
    
                wrong_auth_bits = 0;
                wrong_data_bits = 0;

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

            % Check if message was interpreted right but was false
            % anyway (complementary to the false alarm control), so to
            % interpret false negatives messages - message was accepted
            % but here we are sending only false data, so increment it

            if wrong_auth_bits <= n_allowed_bits_auth
                missed_detection = missed_detection + 1;
            end

            % Assuming encoding is without effect of noise, the decoding is
            % very performing from a practical point of view; so, as
            % condition, we impose the the wrong bits to be dependent on
            % the encoding, so to be just greater than 0

        end
        MD_matrix(j, k) = missed_detection;
        missed_detection = 0;
    end
end