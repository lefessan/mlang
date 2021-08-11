#include "ir_tests.h"
#include <dirent.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        printf("Expected one command-line argument, the file to run\n");
        return -1;
    }

    char line_buffer[1000];
    char *separator = "/";
    char *test_file = argv[1];
    int state;
    m_input *input_for_m = malloc(sizeof(m_input));
    int num_inputs = m_num_inputs();
    m_value *input_array_for_m = malloc(num_inputs * sizeof(m_value));
    int i;
    int num_outputs = m_num_inputs();
    m_value *outputs_array_for_m = malloc(num_outputs * sizeof(m_value));
    m_output *output_for_m = malloc(sizeof(m_output));

    char *name;
    char *value_s;
    int value;
    double expected_value;
    int name_index;
    m_value computed_value;

    FILE *fp = fopen(test_file, "r");
    if (fp == NULL)
    {
        printf("Run file not found!\n");
        return -1;
    }

    // Resetting the arrays
    for (i = 0; i < num_inputs; i++)
    {
        input_array_for_m[i] = m_undefined;
    }
    for (i = 0; i < num_outputs; i++)
    {
        outputs_array_for_m[i] = m_undefined;
    }
    state = 0;
    // 0 - before #ENTREES-PRIMITIF
    // 1 - between #ENTREES-PRIMITIF and #CONTROLES-PRIMITIF
    // 2 - between #CONTROLES-PRIMITIF and #ENTREES-CORRECTIF
    // 3 - after #ENTREES-CORRECTIF
    while (EOF != fscanf(fp, "%[^\n]\n", line_buffer))
    {
        switch (state)
        {
        case 0:
            if (strcmp(line_buffer, "#ENTREES-PRIMITIF") == 0)
            {
                state = 1;
                break;
            }
            // We continue
            break;

        case 1:
            if (strcmp(line_buffer, "#CONTROLES-PRIMITIF") == 0)
            {
                state = 2;
                // Here we move to controlling the outputs, so we
                // have to run the computation!
                m_input_from_array(input_for_m, input_array_for_m);
                for (int i = 0; i < 1000; i++)
                {
                    m_extracted(output_for_m, input_for_m);
                }
                m_output_to_array(outputs_array_for_m, output_for_m);
                break;
            }
            // We parse the inputs
            name = strtok(line_buffer, separator);
            value_s = strtok(NULL, separator);
            value = atoi(value_s);
            name_index = m_get_input_index(name);
            input_array_for_m[name_index] = m_literal(value);
            break;

        case 2:
            if (strcmp(line_buffer, "#ENTREES-CORRECTIF") == 0)
            {
                state = 3;
                break;
            }
            if (strcmp(line_buffer, "#RESULTATS-PRIMITIF") == 0)
            {
                break;
            }
            // We parse the outputs
            name = strtok(line_buffer, separator);
            value_s = strtok(NULL, separator);
            expected_value = atof(value_s);
            name_index = m_get_output_index(name);
            computed_value = outputs_array_for_m[name_index];
            if (computed_value.undefined)
            {
                // Undefined values returned are interpreted as 0
                computed_value.value = 0;
            }
            if (computed_value.value != expected_value)
            {
                printf("Testing file: %s\n", test_file);
                printf("Expected value for %s : %.4f, computed %.4f!\n", name, expected_value, computed_value.value);
                exit(-1);
            }
            break;

        default:
            break;
        }
    }
    fclose(fp);
    free(input_array_for_m);
    free(outputs_array_for_m);
    free(input_for_m);
    free(output_for_m);
    return 0;
}