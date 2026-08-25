# evalQues.py
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

with open("./Sources/model/trainQuesData.json", 'r', encoding='utf-8') as f:
    allData = json.load(f)

import random
random.seed(42)
random.shuffle(allData)
valData = allData[-int(len(allData)*0.1):]
print(f"Size of eval set: {len(valData)}")

formattedValData = []
for data in valData:
    messages = [
        {"role": "system", "content": "你是一个出卷老师，请按照科目、单元、年级、题型出题。题型的类型有choose, fillBlank, answer，分别对应选择/判断、填空、实验探究/解答/综合。数学、科学使用浙教版，英语使用外研版，剩余科目使用人教版。"}, 
        {"role": "user", "content": f"学科：{data['subject']}，年级：{data['grade'][1]}年级{'上册' if data['grade'][0] == 'A' else '下册'}，单元：{data['unit']}，题型：{data['type']}"}, 
        {"role": "assistant", "content": data['output']}
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

checkpoints = [f"./Sources/model/outputQues/checkpoint-{i}" for i in range(11, 111, 11)]
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