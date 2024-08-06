#!/bin/bash

# Define paths to your Python scripts
ULTRASONIC_SCRIPT_PATH="/home/pi/ultrasonic_sensor.py"
OWNER_IDENTIFICATION_SCRIPT_PATH="/home/pi/face_recognition_check.py"
GREETING_SCRIPT_PATH="/home/pi/cv_script.py"
CUSTOMER_INTERACTION_SCRIPT_PATH="/home/pi/chatbot_script.py"

# Function to run the ultrasonic sensor script in the background
run_ultrasonic() {
    echo "Starting ultrasonic sensor script..."
    python3 $ULTRASONIC_SCRIPT_PATH &
    ULTRASONIC_PID=$!
}

# Function to check if a person is detected based on ultrasonic sensor output
check_person_detected() {
    # Implement a check here based on how your ultrasonic script outputs data
    # For example, check if the ultrasonic script outputs "Person Detected"
    # Return 0 if detected, 1 otherwise
    if grep -q "Person Detected" /home/pi/ultrasonic_output.log; then
        return 0
    else
        return 1
    fi
}

# Run the ultrasonic sensor script
run_ultrasonic

while true; do
    # Check if a person is detected
    if check_person_detected; then
        echo "Person detected. Running shop owner identification script..."

        # Run shop owner identification script in background
        python3 $OWNER_IDENTIFICATION_SCRIPT_PATH &
        OWNER_IDENTIFICATION_PID=$!

        # While running owner identification script, continue reading from ultrasonic sensor
        while true; do
            if grep -q "Person Detected" /home/pi/ultrasonic_output.log; then
                # Run shop owner identification script
                if ps -p $OWNER_IDENTIFICATION_PID > /dev/null; then
                    # Shop owner identification is still running
                    echo "Checking for shop owner identification..."
                    if grep -q "Shop Owner Detected" /home/pi/owner_identification_output.log; then
                        echo "Shop owner detected. No further action required."
                        # Continue reading from ultrasonic sensor
                        continue
                    fi
                fi

                # If shop owner not detected, run greeting script
                echo "Running greeting script..."
                python3 $GREETING_SCRIPT_PATH &
                GREETING_PID=$!

                # Monitor for missing person
                while true; do
                    if grep -q "Person Missing" /home/pi/ultrasonic_output.log; then
                        echo "Person missing. Interrupting running scripts..."
                        pkill -P $GREETING_PID
                        pkill -P $OWNER_IDENTIFICATION_PID
                        break
                    fi

                    # Run customer interaction script while greeting script is running
                    echo "Running customer interaction script..."
                    python3 $CUSTOMER_INTERACTION_SCRIPT_PATH &
                    CUSTOMER_INTERACTION_PID=$!

                    # Continue monitoring ultrasonic sensor
                    while true; do
                        if grep -q "Person Missing" /home/pi/ultrasonic_output.log; then
                            echo "Person missing. Interrupting customer interaction script..."
                            pkill -P $CUSTOMER_INTERACTION_PID
                            pkill -P $GREETING_PID
                            break
                        fi
                    done
                done
            else
                # If no person detected, continue monitoring
                sleep 2
            fi
        done
    else
        # If no person detected, continue monitoring
        sleep 2
    fi
done
