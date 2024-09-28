%% SINGLE SIMULATION - TEMPLATE

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

% Generate data signal
binary_data = randi([0, 1], 1, signal_length); % Binary form
% "Real" form - Assigning to each bit its value of relativ power 
for i = 1:signal_length
    if binary_data(i) == 1
        data_signal(i) = power_Y;
    else
        data_signal(i) = power_X;
    end
end

% Generate authentication signal
binary_auth = randi([0, 1], 1, signal_length);
for i = 1:signal_length
    if binary_auth(i) == 1
        authentication_signal(i) = std_th_auth_plus;
    else
        authentication_signal(i) = std_th_auth_minus;
    end
end

% Definition of simulation parameters
% Distance = max. 50 m. with step 1 (from 1 to 50)
% FA rate = increasing rate
% MD rate = increasing rate

% When FA increases, MD decreases
% Conversely, when FA decreases, MD increases
% FA is important but slightly less than MD
% The second one allows to find how many errors we do
% because false positives are slightly different problems

% Conventionally and looking at other sims, we find value to
% be beneath the decimal threshold

% Define simulation parameters
max_distance = 50; % Maximum distance in meters

% Initialize arrays to store target FA and MD rates
target_FA_rates = zeros(max_distance, length(SNR));
target_MD_rates = zeros(max_distance, length(SNR));

% Define ranges for FA rates
min_FA_rate = 0.01; % Minimum FA rate
max_FA_rate = 0.3; % Maximum FA rate
FA_step = 0.01; % FA step size

% Define ranges for MD rates
min_MD_rate = 0.1; % Minimum MD rate
max_MD_rate = 0.5; % Maximum MD rate
MD_step = 0.01; % MD step size

% Generate target FA and MD rates for each distance and SNR
for j = 1:max_distance
    for k = 1:length(SNR)
        % Generate target MD and FA rates with increasing rate for each distance and SNR
        FA_increment = (max_FA_rate - min_FA_rate) / length(SNR);
        target_FA_rates(j, k) = min_FA_rate + (k - 1) * FA_increment;
        
        MD_increment = (max_MD_rate - min_MD_rate) / length(SNR);
        target_MD_rates(j, k) = min_MD_rate + (k - 1) * MD_increment;
    end
end

% Initialize signal S
S = zeros(1, signal_length);

% Combine signals bit by bit
for i = 1:signal_length
    % Combine bits from data_signal and authentication_signal
    S(i) = data_signal(i) + authentication_signal(i);
end

% 10 (data bit 1) + (-5) (auth bit 0) = 5 (discordant bits)
% -10 (data bit 0) + (-5) (auth bit 0) = -15 (concordant bits)
% -10 (data bit 0) + (5) (auth bit 1) = 5 (discordant bits)

% Assuming center is 0 (given the signal is -10 and 10)
center = 0;

wrong_auth_bits = 0;
wrong_data_bits = 0;

n_allowed_bits_auth = 3;

BER_data_vec = zeros(max_distance, length(SNR));
BER_auth_vec = zeros(max_distance, length(SNR));

% Initialize arrays to store received data and authentication bits
received_data = zeros(1, signal_length);
received_auth = zeros(1, signal_length);

% Loop through each distance
for j = 1:max_distance
    % Loop through each SNR level
    for k = 1:length(SNR)
        % Generate the received signal by adding AWGN
        received_signal = awgn(S, SNR(k));

        % Zeroing bits at every iteration
        wrong_data_bits = 0;
        wrong_auth_bits = 0;

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

        % Calculate BER for the current iteration
        BER_data = wrong_data_bits / signal_length;
        BER_auth = wrong_auth_bits / signal_length;

        % Zeroing at every iteration
        wrong_auth_bits = 0;
        wrong_data_bits = 0;
        
        if wrong_auth_bits > n_allowed_bits_auth
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

            % Calculate BER for the current iteration considering 
            % the new variable thresholds decoding
            BER_data = wrong_data_bits / signal_length;
            BER_auth = wrong_auth_bits / signal_length;

            % Store BER values in the vectors
            BER_data_vec(j, k) = BER_data;
            BER_auth_vec(j, k) = BER_auth;
        end
    end
end


