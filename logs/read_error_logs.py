import csv

# Specify the input and output file names
input_file_name = '/Users/pasindu/Downloads/query_data.csv'
output_file_name = 'processed_error_logs.txt'  # Change to .csv if you prefer a CSV output

# Open the input file and the output file
with open(input_file_name, mode='r', newline='', encoding='utf-8') as infile, \
     open(output_file_name, mode='w', newline='', encoding='utf-8') as outfile:

    # Create a CSV reader and writer
    reader = csv.reader(infile)
    # For CSV output, use: writer = csv.writer(outfile)
    writer = outfile  # Directly write to the text file

    # Iterate over each row in the input CSV file
    for row in reader:
        # For CSV output, use: writer.writerow(row)
        # Convert row to string and write to text file, assuming comma-separated
        writer.write(','.join(row) + '\n')
        
        # Add an extra newline after each row for the line space
        writer.write('\n')  # For CSV output, you might still want to use this line

print(f'Processed error logs have been written to {output_file_name}')
