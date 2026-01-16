#!/usr/bin/env python3
"""
Performance Test Results Analyzer
Analyzes Locust CSV outputs and generates comparison reports
"""

import pandas as pd
import matplotlib.pyplot as plt
import sys
from pathlib import Path

def analyze_test_results(results_dir):
    """Analyze all test results in the directory"""
    
    results_path = Path(results_dir)
    
    # Find all stats files
    stats_files = list(results_path.glob("*_stats.csv"))
    
    if not stats_files:
        print(f"No stats files found in {results_dir}")
        return
    
    # Collect summary data
    summary_data = []
    
    for stats_file in sorted(stats_files):
        test_name = stats_file.stem.replace("_stats", "")
        
        try:
            df = pd.read_csv(stats_file)
            aggregated = df[df['Name'] == 'Aggregated']
            
            if aggregated.empty:
                continue
            
            row = aggregated.iloc[0]
            
            summary_data.append({
                'Test': test_name,
                'Total Requests': row['Request Count'],
                'Failures': row['Failure Count'],
                'Error Rate (%)': (row['Failure Count'] / row['Request Count'] * 100) if row['Request Count'] > 0 else 0,
                'RPS': row['Requests/s'],
                'Median RT (ms)': row['Median Response Time'],
                'P95 RT (ms)': row['95%'],
                'P99 RT (ms)': row['99%'],
                'Min RT (ms)': row['Min Response Time'],
                'Max RT (ms)': row['Max Response Time'],
            })
        except Exception as e:
            print(f"Error processing {stats_file}: {e}")
    
    if not summary_data:
        print("No valid data found")
        return
    
    # Create summary DataFrame
    summary_df = pd.DataFrame(summary_data)
    
    # Print summary table
    print("\n" + "="*80)
    print("PERFORMANCE TEST SUMMARY")
    print("="*80 + "\n")
    print(summary_df.to_string(index=False))
    print("\n" + "="*80 + "\n")
    
    # Save to CSV
    summary_df.to_csv(results_path / "summary.csv", index=False)
    print(f"Summary saved to: {results_path / 'summary.csv'}")
    
    # Generate plots
    generate_plots(summary_df, results_path)
    
    return summary_df

def generate_plots(df, output_dir):
    """Generate visualization plots"""
    
    fig, axes = plt.subplots(2, 3, figsize=(18, 12))
    fig.suptitle('Performance Test Results Overview', fontsize=16, fontweight='bold')
    
    # Extract test labels and user counts from test names
    test_labels = df['Test'].tolist()
    
    # 1. Response Time Comparison
    ax = axes[0, 0]
    x = range(len(df))
    width = 0.25
    ax.bar([i - width for i in x], df['Median RT (ms)'], width, label='Median', color='blue', alpha=0.7)
    ax.bar(x, df['P95 RT (ms)'], width, label='P95', color='orange', alpha=0.7)
    ax.bar([i + width for i in x], df['P99 RT (ms)'], width, label='P99', color='red', alpha=0.7)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Response Time (ms)')
    ax.set_title('Response Time Distribution')
    ax.set_xticks(x)
    ax.set_xticklabels(test_labels, rotation=45, ha='right')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 2. Throughput (RPS)
    ax = axes[0, 1]
    ax.bar(test_labels, df['RPS'], color='green', alpha=0.7)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Requests per Second')
    ax.set_title('Throughput Comparison')
    ax.tick_params(axis='x', rotation=45)
    ax.grid(True, alpha=0.3)
    
    # 3. Error Rate
    ax = axes[0, 2]
    colors = ['red' if x > 1 else 'green' for x in df['Error Rate (%)']]
    ax.bar(test_labels, df['Error Rate (%)'], color=colors, alpha=0.7)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Error Rate (%)')
    ax.set_title('Error Rate Comparison')
    ax.axhline(y=1, color='r', linestyle='--', label='1% threshold')
    ax.tick_params(axis='x', rotation=45)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 4. Response Time Range (Min/Max)
    ax = axes[1, 0]
    ax.fill_between(range(len(df)), df['Min RT (ms)'], df['Max RT (ms)'], alpha=0.3, label='Range')
    ax.plot(df['Median RT (ms)'], 'o-', label='Median', linewidth=2)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Response Time (ms)')
    ax.set_title('Response Time Range')
    ax.set_xticks(range(len(df)))
    ax.set_xticklabels(test_labels, rotation=45, ha='right')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 5. Total Requests
    ax = axes[1, 1]
    ax.bar(test_labels, df['Total Requests'], color='purple', alpha=0.7)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Total Requests')
    ax.set_title('Total Requests Processed')
    ax.tick_params(axis='x', rotation=45)
    ax.grid(True, alpha=0.3)
    
    # 6. Performance Score (RPS / P95 RT)
    ax = axes[1, 2]
    performance_score = df['RPS'] / (df['P95 RT (ms)'] / 1000)  # Normalize by P95 in seconds
    ax.bar(test_labels, performance_score, color='teal', alpha=0.7)
    ax.set_xlabel('Test Scenario')
    ax.set_ylabel('Performance Score (RPS/P95)')
    ax.set_title('Overall Performance Score')
    ax.tick_params(axis='x', rotation=45)
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    output_file = output_dir / 'performance_analysis.png'
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Plots saved to: {output_file}")
    plt.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_results.py <results_directory>")
        print("Example: python3 analyze_results.py ~/gke-performance-results")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    analyze_test_results(results_dir)