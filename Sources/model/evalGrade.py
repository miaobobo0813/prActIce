# evalGrade.py
# type: ignore

import os
import json
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
from datasets import Dataset
import torch

MODELNAME = "Qwen/Qwen2.5-0.5B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(MODELNAME, trust_remote_code=True)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token
baseModel = AutoModelForCausalLM.from_pretrained(MODELNAME, trust_remote_code=True, dtype="auto", device_map="auto")

with open("./Sources/model/trainGradeData.json", 'r', encoding='utf-8') as f:
    allData = json.load(f)

import random
random.seed(42)
random.shuffle(allData)
valData = allData[-int(len(allData)*0.1):]
print(f"Size of eval set: {len(valData)}")

formattedValData = []
for data in valData:
    output = str(data.get("output", "0/1"))
    messages = [
        {"role": "system", "content": "你是一个批改作业的老师。请根据题目类型进行评分：选择题和填空题每空1分，若回答正确则输出 1/1；若回答错误则输出 0/1；若题目包含多个空，请按空数给出如 2/3 或 1/3 的分数。请只输出最终评分结果，不要解释。"}, 
        {"role": "user", "content": f"问题：{data['question']}，学生回答；{data['userAnswer']}"}, 
        {"role": "assistant", "content": output}
    ]
    fullText = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
    inputID = tokenizer(fullText, truncation=True, max_length=1024)["input_ids"]
    promptText = tokenizer.apply_chat_template(messages[:-1], tokenize=False, add_generation_prompt=True)
    promptIDs = tokenizer(promptText, add_special_tokens=False)["input_ids"]
    labels = inputID.copy()
    promptLen = len(promptIDs)
    labels[:promptLen] = [-100]*promptLen
    formattedValData.append({"input_ids": inputID, "labels": labels})

val_dataset = Dataset.from_list(formattedValData)

checkpoints = [f"./Sources/model/outputGrade/checkpoint-{i}" for i in range(11, 111, 11)]
existing_checkpoints = [ckpt for ckpt in checkpoints if os.path.exists(ckpt)]
print(f"Find {len(existing_checkpoints)} checkpoints")

results = {}
for ckpt in existing_checkpoints:
    try:
        model = PeftModel.from_pretrained(baseModel, ckpt)
        model.eval()
        
        total_loss = 0
        with torch.no_grad():
            for batch in val_dataset:
                inputs = {
                    "input_ids": torch.tensor([batch["input_ids"]], device=model.device),
                    "labels": torch.tensor([batch["labels"]], device=model.device)
                }
                outputs = model(**inputs)
                total_loss += outputs.loss.item()
        
        avg_loss = total_loss / len(val_dataset)
        results[ckpt] = avg_loss
        print(f"{ckpt}: Eval set loss = {avg_loss:.6f}")
        
        del model
        torch.cuda.empty_cache()
        
    except Exception as e:
        print(f"  Eval error: {e}")
        results[ckpt] = float('inf')

if results:
    valid_results = {k: v for k, v in results.items() if v != float('inf')}
    if valid_results:
        best_ckpt = min(valid_results, key=lambda x: valid_results[x])
        print(f"\n{'='*50}")
        print(f"Best checkpoint: {os.path.basename(best_ckpt)}")
        print(f"Eval set loss: {valid_results[best_ckpt]:.6f}")
        print(f"{'='*50}")
        
        print("\nAll checkpoints(sort by loss):")
        sorted_results = sorted(valid_results.items(), key=lambda x: x[1])
        for i, (ckpt, loss) in enumerate(sorted_results, 1):
            print(f"  {i}. {os.path.basename(ckpt)}: {loss:.6f}")
    else:
        print("None of checkpoints has been evaled.")